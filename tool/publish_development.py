#!/usr/bin/env python3
"""Publish through the serialized Publish development GitHub workflow only.

APKs are cryptographically verified by Android apksigner. Immutable assets from
all development generations remain available for clients with cached manifests.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

REPO = 'delwaqtyapp/delwaqty'
SIGNER = 'ad4e2f47be742f3c08bd5e97223b3e7fcc366ad958691995e6dbd52a4a77dc55'
FLAVORS = ('customer', 'admin', 'driver', 'provider')
WORKFLOW = f'{REPO}/.github/workflows/publish-development.yml@refs/heads/master'
# Reviewed one-time reuse of the complete green auth-cutover CI artifacts.
REUSE_SOURCE = 'c54f633eb26c3f8aaea783fa2e12149ed58eb650'
REUSE_HASHES = {
    'customer': '9a333f59edf49d11a3c1c66373904783236c4cf1b5643901bdd66bf40c086226',
    'admin': 'ccc15e8afa53c90e489fe5377af9fde6c5ed87f52b659ace05b207672ff7f565',
    'driver': '603094dbe40b81faf9cbdaa024be319c0e4f7d99c409a3fb8bd27e3db0a5b8f2',
    'provider': 'fe366738e63884ea45119112cd9b3c1b8b5cfb4939356ee71ebf41360eae4255',
}
PUBLISHER_FILES = {'.github/workflows/publish-development.yml', 'tool/publish_development.py'}


def gh(*args):
    return subprocess.check_output(['gh', *args], text=True).strip()


def apksigner_path():
    pinned = os.environ.get('APKSIGNER')
    if pinned:
        if not Path(pinned).is_file():
            raise SystemExit('Pinned Android apksigner is missing')
        return pinned
    direct = shutil.which('apksigner')
    if direct:
        return direct
    for variable in ('ANDROID_HOME', 'ANDROID_SDK_ROOT'):
        home = os.environ.get(variable)
        if not home:
            continue
        paths = list((Path(home) / 'build-tools').glob('*/apksigner'))
        if paths:
            return str(sorted(paths, key=lambda p: tuple(
                int(n) for n in re.findall(r'\d+', p.parent.name)))[-1])
    raise SystemExit('Android apksigner is required; no certificate-only fallback')


def verify_apk(path, executable):
    # A certificate extracted from an APK is NOT evidence of a valid signature.
    # apksigner validates the actual APK bytes and returns nonzero on tampering.
    result = subprocess.run(
        [executable, 'verify', '--verbose', '--print-certs', str(path)],
        text=True, capture_output=True, check=True,
    )
    signers = re.findall(
        r'^Signer #\d+ certificate SHA-256 digest:\s*([0-9a-fA-F]{64})\s*$',
        result.stdout, re.M,
    )
    if not signers or {s.lower() for s in signers} != {SIGNER}:
        raise SystemExit(f'APK signer validation failed with {executable}:\n{result.stdout}\n{result.stderr}')


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()


def validate_floor(build, manifest, allow_same=False):
    channels = manifest.get('channels', {})
    if set(channels) != set(FLAVORS):
        raise SystemExit('Prior manifest must contain all four build floors')
    for channel in channels.values():
        floor = channel.get('version')
        if (not isinstance(floor, int) or isinstance(floor, bool)
                or build < floor or (build == floor and not allow_same)):
            raise SystemExit('Build code must exceed every prior latest build')


def release_manifest(release):
    matches = [a for a in release['assets'] if a['name'] == 'versions.json']
    if len(matches) != 1:
        raise SystemExit('Prior published release has no unambiguous manifest')
    return json.loads(gh('api', f'repos/{REPO}/releases/assets/{matches[0]["id"]}',
                         '-H', 'Accept: application/octet-stream'))


def require_current_master(sha):
    if gh('api', f'repos/{REPO}/commits/master', '--jq', '.sha') != sha:
        raise SystemExit('Refusing stale CI commit: master moved')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', help='Fully green CI/CD run ID')
    args = parser.parse_args()
    # The supported execution path has a cross-run concurrency lock. Do not
    # run this script locally: an OS-only lock cannot serialize other machines.
    if (os.environ.get('GITHUB_ACTIONS') != 'true'
            or os.environ.get('GITHUB_WORKFLOW_REF') != WORKFLOW
            or os.environ.get('GITHUB_REF') != 'refs/heads/master'):
        raise SystemExit('Use the serialized Publish development workflow on master')
    executable = apksigner_path()
    run = json.loads(gh('run', 'view', args.run, '-R', REPO, '--json',
                        'headSha,status,conclusion,jobs,workflowName'))
    required = {'Analyze & Format', 'Test'} | {f'Build APK ({f})' for f in FLAVORS}
    jobs = {job['name']: job['conclusion'] for job in run['jobs']}
    if (run['workflowName'] != 'CI/CD' or run['status'] != 'completed'
            or run['conclusion'] != 'success' or not required.issubset(jobs)
            or any(value != 'success' for value in jobs.values())):
        raise SystemExit('Entire expected CI/CD run must be green')
    publisher_sha = os.environ['GITHUB_SHA']
    require_current_master(publisher_sha)
    reuse = run['headSha'] != publisher_sha
    if reuse:
        if run['headSha'] != REUSE_SOURCE or args.run != '45059792149':
            raise SystemExit('Only the reviewed c54 auth-cutover artifacts may be reused')
        comparison = json.loads(gh('api', f'repos/{REPO}/compare/{REUSE_SOURCE}...{publisher_sha}'))
        files = comparison.get('files', [])
        if (comparison.get('status') != 'ahead' or not files or len(files) > 2
                or any(f['filename'] not in PUBLISHER_FILES or f['status'] != 'modified' for f in files)):
            raise SystemExit('Artifact reuse requires a publisher-only diff')
    pubspec = gh('api', f'repos/{REPO}/contents/pubspec.yaml?ref={run["headSha"]}',
                 '-H', 'Accept: application/vnd.github.raw+json')
    match = re.search(r'^version:\s*([\d.]+)\+(\d+)\s*$', pubspec, re.M)
    if not match or match[1] != '1.0.0':
        raise SystemExit('Development versionName must stay 1.0.0')
    version, build = match[1], int(match[2])
    tag = 'development'
    releases = json.loads(gh('api', f'repos/{REPO}/releases?per_page=100'))
    release = next((r for r in releases if r['tag_name'] == tag), None)
    latest = json.loads(gh('api', f'repos/{REPO}/releases/latest'))
    latest_manifest = release_manifest(latest)
    validate_floor(build, latest_manifest, allow_same=latest['tag_name'] == tag)
    old = release_manifest(release) if release and not release['draft'] else None
    if old:
        validate_floor(build, old, allow_same=True)
    with tempfile.TemporaryDirectory(prefix='delwaqty-development-') as temp:
        root = Path(temp)
        gh('run', 'download', args.run, '-R', REPO, '-p', '*-release-*', '-D', temp)
        manifest = {'sourceCommit': run['headSha'], 'channels': {}}
        apks = []
        for flavor in FLAVORS:
            candidates = list(root.glob(f'**/app-{flavor}-release.apk'))
            if len(candidates) != 1:
                raise SystemExit(f'Ambiguous APK: {flavor}')
            verify_apk(candidates[0], executable)
            if reuse and digest(candidates[0]) != REUSE_HASHES[flavor]:
                raise SystemExit(f'Reused artifact hash mismatch: {flavor}')
            name = f'delwaqty-{flavor}-{build}.apk'
            target = root / name
            candidates[0].rename(target)
            apks.append(target)
            manifest['channels'][flavor] = {
                'version': build, 'versionName': version, 'apk': name,
                'sha256': digest(target), 'notes': 'تحسينات وإصلاحات نسخة التطوير',
            }
        if old and any(c['version'] == build for c in old['channels'].values()):
            if old != manifest:
                raise SystemExit('Different payload at an existing build code')
        manifest_path = root / 'versions.json'
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
        if release is None:
            gh('release', 'create', tag, '-R', REPO, '--draft', '--target', run['headSha'],
               '--title', 'Development build', '--notes', 'Current development build.')
        existing_names = {a['name'] for a in release['assets']} if release else set()
        check = root / 'verify'
        check.mkdir()
        # Never replace an immutable APK, even on retry. Verify existing bytes.
        for apk in apks:
            if apk.name not in existing_names:
                gh('release', 'upload', tag, '-R', REPO, str(apk))
            gh('release', 'download', tag, '-R', REPO, '-p', apk.name, '-D', str(check))
            if digest(check / apk.name) != digest(apk):
                raise SystemExit(f'Round-trip checksum failed: {apk.name}')
            verify_apk(check / apk.name, executable)
        # Recheck after downloads; a new master must get its own successful CI.
        require_current_master(publisher_sha)
        gh('release', 'upload', tag, '-R', REPO, str(manifest_path), '--clobber')
        gh('release', 'download', tag, '-R', REPO, '-p', 'versions.json', '-D', str(check))
        if json.loads((check / 'versions.json').read_text()) != manifest:
            raise SystemExit('Round-trip manifest mismatch')
        gh('release', 'edit', tag, '-R', REPO, '--draft=false', '--prerelease=false', '--latest',
           '--title', 'Development build', '--notes',
           f'Current development build. Visible app version: 1.0.0. Source commit: {run["headSha"]}.')
        # Keep ALL development APK generations while this tag is active.
        # Older clients can retain old manifests for an unbounded time.
        current = json.loads(gh('release', 'view', tag, '-R', REPO, '--json', 'url,assets'))
        print(json.dumps({'url': current['url'], 'commit': run['headSha'],
                          'build': build, 'sha256': {f: c['sha256'] for f, c in manifest['channels'].items()}}, indent=2))


if __name__ == '__main__':
    main()
