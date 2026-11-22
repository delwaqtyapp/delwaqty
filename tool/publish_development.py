#!/usr/bin/env python3
"""Publish a CI-verified build to the single development release.

Requires gh authentication. Never builds locally or sends notifications.
Upload APKs first and replace versions.json last. Old build assets are removed
only after all newly uploaded assets have passed round-trip SHA-256 checks.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import tempfile

REPO = 'delwaqtyapp/delwaqty'
SIGNER = 'ad4e2f47be742f3c08bd5e97223b3e7fcc366ad958691995e6dbd52a4a77dc55'
FLAVORS = ('customer', 'admin', 'driver', 'provider')


def gh(*args):
    return subprocess.check_output(['gh', *args], text=True).strip()


def cert_fingerprint(path):
    data = path.read_bytes()
    end = data.rfind(b'PK\x05\x06')
    if end < 0:
        raise ValueError('APK ZIP directory missing')
    central = struct.unpack_from('<I', data, end + 16)[0]
    if data[central - 16:central] != b'APK Sig Block 42':
        raise ValueError('APK v2 signing block missing')
    size = struct.unpack_from('<Q', data, central - 24)[0]
    pos = central - size
    while pos < central - 24:
        length = struct.unpack_from('<Q', data, pos)[0]
        if length < 4:
            raise ValueError('Malformed signing block')
        if struct.unpack_from('<I', data, pos + 8)[0] == 0x7109871a:
            # Length-prefixed signers, signer, signed data, digests, certificates.
            cursor = pos + 12 + 12
            digests = struct.unpack_from('<I', data, cursor)[0]
            cursor += 4 + digests
            cursor += 4  # certificates sequence length
            cert_length = struct.unpack_from('<I', data, cursor)[0]
            cursor += 4
            return hashlib.sha256(data[cursor:cursor + cert_length]).hexdigest()
        pos += length + 8
    raise ValueError('No APK v2 signer found')


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', help='Fully green CI/CD run ID')
    args = parser.parse_args()
    run = json.loads(gh('run', 'view', args.run, '-R', REPO, '--json',
                        'headSha,status,conclusion,jobs,workflowName'))
    required = {'Analyze & Format', 'Test'} | {f'Build APK ({f})' for f in FLAVORS}
    jobs = {job['name']: job['conclusion'] for job in run['jobs']}
    if (run['workflowName'] != 'CI/CD' or run['status'] != 'completed'
            or run['conclusion'] != 'success'
            or not required.issubset(jobs)
            or any(value != 'success' for value in jobs.values())):
        raise SystemExit('Refusing publish: entire expected CI/CD run must be green')
    if gh('api', f'repos/{REPO}/commits/master', '--jq', '.sha') != run['headSha']:
        raise SystemExit('Refusing stale build: CI commit is not current master')
    pubspec = gh('api', f'repos/{REPO}/contents/pubspec.yaml?ref={run["headSha"]}',
                 '-H', 'Accept: application/vnd.github.raw+json')
    match = re.search(r'^version:\s*([\d.]+)\+(\d+)\s*$', pubspec, re.M)
    if not match or match[1] != '1.0.0':
        raise SystemExit('Development versionName must stay 1.0.0')
    version, build = match[1], int(match[2])
    tag = 'development'
    releases = json.loads(gh('api', f'repos/{REPO}/releases?per_page=100'))
    release = next((r for r in releases if r['tag_name'] == tag), None)
    old = None
    if release and not release['draft']:
        assets = release['assets']
        old_manifests = [a for a in assets if a['name'] == 'versions.json']
        if old_manifests:
            old = json.loads(gh('api', f'repos/{REPO}/releases/assets/{old_manifests[0]["id"]}',
                                '-H', 'Accept: application/octet-stream'))
            if any(c['version'] > build for c in old['channels'].values()):
                raise SystemExit('Refusing non-increasing build code')
    with tempfile.TemporaryDirectory(prefix='delwaqty-development-') as temp:
        root = Path(temp)
        gh('run', 'download', args.run, '-R', REPO, '-p', '*-release-*', '-D', temp)
        manifest = {'sourceCommit': run['headSha'], 'channels': {}}
        apks = []
        for flavor in FLAVORS:
            candidates = list(root.glob(f'**/app-{flavor}-release.apk'))
            if len(candidates) != 1 or cert_fingerprint(candidates[0]) != SIGNER:
                raise SystemExit(f'Refusing invalid or ambiguous signer: {flavor}')
            name = f'delwaqty-{flavor}-{build}.apk'
            target = root / name
            candidates[0].rename(target)
            apks.append(str(target))
            manifest['channels'][flavor] = {
                'version': build, 'versionName': version, 'apk': name,
                'sha256': digest(target), 'notes': 'تحسينات وإصلاحات نسخة التطوير',
            }
        if old and any(c['version'] == build for c in old['channels'].values()):
            if old != manifest:
                raise SystemExit('Refusing a different payload at an existing build code')
        manifest_path = root / 'versions.json'
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
        if release is None:
            gh('release', 'create', tag, '-R', REPO, '--draft', '--target', run['headSha'],
               '--title', 'Development build', '--notes',
               'Current development build. Visible app version: 1.0.0. Internal build codes increase for OTA updates.')
        # New immutable APK names first. A failed upload leaves the old manifest intact.
        gh('release', 'upload', tag, '-R', REPO, *apks, '--clobber')
        check = root / 'verify'
        check.mkdir()
        for flavor, config in manifest['channels'].items():
            gh('release', 'download', tag, '-R', REPO, '-p', config['apk'], '-D', str(check))
            if digest(check / config['apk']) != config['sha256']:
                raise SystemExit(f'Round-trip checksum failed: {flavor}')
        gh('release', 'upload', tag, '-R', REPO, str(manifest_path), '--clobber')
        gh('release', 'download', tag, '-R', REPO, '-p', 'versions.json', '-D', str(check))
        if json.loads((check / 'versions.json').read_text()) != manifest:
            raise SystemExit('Round-trip manifest mismatch')
        gh('release', 'edit', tag, '-R', REPO, '--draft=false', '--prerelease=false', '--latest',
           '--title', 'Development build', '--notes',
           f'Current development build. Visible app version: 1.0.0. Source commit: {run["headSha"]}.')
        current = json.loads(gh('release', 'view', tag, '-R', REPO, '--json', 'url,assets'))
        keep = {'versions.json'} | {Path(p).name for p in apks}
        for asset in current['assets']:
            if asset['name'] not in keep:
                gh('release', 'delete-asset', tag, asset['name'], '-R', REPO, '--yes')
        print(json.dumps({'url': current['url'], 'commit': run['headSha'],
                          'build': build, 'sha256': {f: c['sha256'] for f, c in manifest['channels'].items()}}, indent=2))


if __name__ == '__main__':
    main()
