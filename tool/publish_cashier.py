#!/usr/bin/env python3
"""Merge the cashier OTA channels into the release manifest. Fail-closed.

The manifest (versions.json on the rolling development release) is shared
with the four Flutter apps. A cashier publish that downloaded nothing, hit
an auth/network error, or saw a schema it did not expect must abort BEFORE
any upload: it must never overwrite the manifest with empty channels and
erase the Flutter apps' update path. Unknown channels and top-level keys
are preserved verbatim; only cashier-net8/cashier-net48 are replaced.

Serialization is the shared delwaqty-development-publisher concurrency
group (pos-windows.yml and publish-development.yml carry the same group
with cancel-in-progress: false), so this merge never interleaves with the
Flutter publisher. Runs ONLY inside that workflow.
"""
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

REPO = 'delwaqtyapp/delwaqty'
TAG = 'development'
CHANNELS = ('cashier-net8', 'cashier-net48')
# The workflow must run from the default branch, and the publisher code
# itself is checked out at PUBLISHER_SHA - a reviewed master commit pinned
# in pos-windows.yml - never from the branch being published.
WORKFLOW = f'{REPO}/.github/workflows/pos-windows.yml@refs/heads/master'
NOTES = 'تحديث الكاشير'
MAX_INSTALLER_BYTES = 500 * 1024 * 1024
SHA_RE = re.compile(r'[0-9a-f]{40}')
# Immutable, version- and runtime-specific installer names. The manifest
# entry points at exactly this artifact, so a cached client can never pick
# up a silently replaced binary.
ASSET_NAME = re.compile(r'^delwaqty-cashier-setup-(net8|net48)-b[0-9]+\.exe$')
ZIP_NAME = re.compile(r'^delwaqty-cashier-windows-b[0-9]+\.zip$')


def gh(*args):
    return subprocess.check_output(['gh', *args], text=True).strip()


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()


def validate_manifest(doc):
    """Schema check on the downloaded manifest. Any doubt means abort."""
    if not isinstance(doc, dict) or not isinstance(doc.get('channels'), dict):
        raise SystemExit('Downloaded manifest failed the schema check')
    if not doc['channels']:
        # An empty manifest means the Flutter channels are already gone;
        # publishing into it would bless the erasure. Abort.
        raise SystemExit('Downloaded manifest has no channels; refusing to publish')
    for name, channel in doc['channels'].items():
        if not isinstance(name, str) or not isinstance(channel, dict):
            raise SystemExit('Downloaded manifest failed the schema check')
        version = channel.get('version')
        if not isinstance(version, int) or isinstance(version, bool) or version <= 0:
            raise SystemExit(f'Channel {name} has no valid monotonic version')
        for key in ('versionName', 'apk', 'notes'):
            if key in channel and not isinstance(channel[key], str):
                raise SystemExit(f'Channel {name} field {key} is not a string')
        if 'sha256' in channel and not (
                isinstance(channel['sha256'], str)
                and re.fullmatch(r'[0-9a-f]{64}', channel['sha256'])):
            raise SystemExit(f'Channel {name} has a malformed sha256')
    return doc


def fetch_manifest(directory):
    """Fail-closed read of the live manifest. NO empty-manifest fallback."""
    try:
        gh('release', 'download', TAG, '-R', REPO, '-p', 'versions.json',
           '--clobber', '-D', str(directory))
    except subprocess.CalledProcessError as exc:
        raise SystemExit(f'Refusing to publish: manifest download failed ({exc.returncode}). '
                         'Never overwrite the shared manifest on a read failure.')
    try:
        doc = json.loads((Path(directory) / 'versions.json').read_text())
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f'Refusing to publish: manifest unreadable ({exc})')
    return validate_manifest(doc)


def check_monotonic(manifest, build):
    """A publish may only move its own channels forward."""
    for name in CHANNELS:
        current = manifest['channels'].get(name)
        if current and current['version'] >= build:
            raise SystemExit(
                f'{name} is already at {current["version"]}; refusing non-forward publish {build}')


def merge(manifest, build, assets):
    """assets: {channel: (versioned_asset_name, sha256)}. Preserves everything else."""
    merged = copy.deepcopy(manifest)
    for name in CHANNELS:
        asset_name, sha = assets[name]
        merged['channels'][name] = {
            'version': build,
            'versionName': f'1.0.0-b{build}',
            'apk': asset_name,
            'notes': NOTES,
            'sha256': sha,
        }
    return validate_manifest(merged)


def check_provenance(directory, build):
    """The artifacts must come from THIS run's build job, which exported
    the resolved build commit as a job output and wrote this file into the
    artifact. Anything else is the wrong payload.
    """
    try:
        prov = json.loads((Path(directory) / 'build-provenance.json').read_text())
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f'Build provenance missing or unreadable: {exc}')
    if (prov.get('run_id') != os.environ.get('GITHUB_RUN_ID')
            or prov.get('run_number') != build
            or not isinstance(prov.get('sha'), str)
            or not SHA_RE.fullmatch(prov['sha'])):
        raise SystemExit('Build provenance does not match this run and build')
    return prov['sha']


def verify_installer(path, build):
    name = Path(path).name
    match = ASSET_NAME.fullmatch(name)
    if not match or int(name.rsplit('-b', 1)[1][:-4]) != build:
        raise SystemExit(f'Installer name does not pin runtime and build: {name}')
    size = Path(path).stat().st_size
    if size == 0 or size > MAX_INSTALLER_BYTES:
        raise SystemExit(f'Installer size out of bounds: {name} ({size} bytes)')
    return name


def main():
    if len(os.sys.argv) != 5:
        raise SystemExit('usage: publish_cashier.py BUILD ZIP NET8_INSTALLER NET48_INSTALLER')
    build = int(os.sys.argv[1])
    zip_path, net8_path, net48_path = os.sys.argv[2], os.sys.argv[3], os.sys.argv[4]
    if build <= 0:
        raise SystemExit('Build number must be positive')
    # The supported execution path has a cross-run concurrency lock. Do not
    # run this script locally: an OS-only lock cannot serialize other machines.
    # The workflow itself must run on the default branch and the publisher
    # code must be pinned to a reviewed master commit - never the published
    # branch's code.
    if (os.environ.get('GITHUB_ACTIONS') != 'true'
            or os.environ.get('GITHUB_WORKFLOW_REF') != WORKFLOW
            or not SHA_RE.fullmatch(os.environ.get('PUBLISHER_SHA', ''))):
        raise SystemExit('Use the serialized POS Windows cashier workflow on master, '
                         'with PUBLISHER_SHA pinned to the reviewed publisher commit')
    zip_name = Path(zip_path).name
    if not ZIP_NAME.fullmatch(zip_name) or int(zip_name[:-4].rsplit('-b', 1)[1]) != build:
        raise SystemExit(f'Zip name does not pin the build: {zip_name}')
    check_provenance(str(Path(zip_path).parent), build)
    installers = {
        'cashier-net8': verify_installer(net8_path, build),
        'cashier-net48': verify_installer(net48_path, build),
    }
    paths = {'cashier-net8': Path(net8_path), 'cashier-net48': Path(net48_path)}
    existing = {a['name'] for a in json.loads(
        gh('release', 'view', TAG, '-R', REPO, '--json', 'assets'))['assets']}
    with tempfile.TemporaryDirectory(prefix='delwaqty-cashier-') as temp:
        root = Path(temp)
        # Immutable, versioned assets are NEVER clobbered. On a retry an
        # existing asset is kept and only re-proven (idempotent). Post-upload
        # hash proof covers the bytes clients will actually fetch.
        payloads = dict(paths)
        payloads['zip'] = Path(zip_path)
        names = dict(installers)
        names['zip'] = zip_name
        for key, name in names.items():
            local = digest(payloads[key])
            if name not in existing:
                gh('release', 'upload', TAG, '-R', REPO, str(payloads[key]))
            check = root / 'verify'
            check.mkdir(exist_ok=True)
            gh('release', 'download', TAG, '-R', REPO, '-p', name,
               '--clobber', '-D', str(check))
            if digest(check / name) != local:
                raise SystemExit(f'Post-upload hash proof failed: {name}')
            if key in installers:
                installers[key] = (name, local)
        # Read/validate/merge/upload the shared manifest, then prove the
        # round trip. Every failure above this line left the manifest alone.
        manifest = fetch_manifest(root)
        check_monotonic(manifest, build)
        merged = merge(manifest, build, installers)
        merged_path = root / 'versions.json'
        merged_path.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + '\n')
        gh('release', 'upload', TAG, '-R', REPO, str(merged_path), '--clobber')
        check2 = root / 'verify2'
        check2.mkdir()
        roundtrip = fetch_manifest(check2)
        if roundtrip != merged:
            raise SystemExit('Round-trip manifest mismatch')
        print(json.dumps({'channels': {c: installers[c][1] for c in CHANNELS},
                          'build': build}, indent=2))


if __name__ == '__main__':
    main()
