#!/usr/bin/env python3
"""Attach the cashier zip and installers to the development release. Fail-closed.

Cashier assets are immutable, build-numbered files. This publisher NEVER
reads or writes versions.json (the Flutter update manifest): the cashier has
no in-app update in this release, the family reinstalls by hand. Existing
assets are never clobbered; a retry re-proves them by hash. Runs ONLY inside
the serialized pos-windows.yml workflow on master, from the master commit
that started the run (never from the built ref).
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
# The workflow must run from the default branch; the publisher code is the
# master commit that started the run, never the built ref.
WORKFLOW = f'{REPO}/.github/workflows/pos-windows.yml@refs/heads/master'
MAX_INSTALLER_BYTES = 500 * 1024 * 1024
SHA_RE = re.compile(r'[0-9a-f]{40}')
# Immutable, version- and runtime-specific installer names. The release asset
# name pins the runtime and build, so a retry or a cached download can never pick
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


def check_provenance(directory, build):
    """The artifacts must come from THIS run's build job, which exported
    the resolved build commit as a job output (BUILD_SHA) and wrote this
    file into the artifact. Both must agree; anything else is the wrong
    payload.
    """
    build_sha = os.environ.get('BUILD_SHA', '')
    if not SHA_RE.fullmatch(build_sha):
        raise SystemExit('BUILD_SHA (the build job\'s resolved commit) is missing')
    try:
        prov = json.loads((Path(directory) / 'build-provenance.json').read_text())
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f'Build provenance missing or unreadable: {exc}')
    if (prov.get('run_id') != os.environ.get('GITHUB_RUN_ID')
            or prov.get('run_number') != build
            or not isinstance(prov.get('sha'), str)
            or not SHA_RE.fullmatch(prov['sha'])):
        raise SystemExit('Build provenance does not match this run and build')
    if prov['sha'] != build_sha:
        raise SystemExit('Provenance commit does not match the build job output')
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
    if (os.environ.get('GITHUB_ACTIONS') != 'true'
            or os.environ.get('GITHUB_WORKFLOW_REF') != WORKFLOW
            or os.environ.get('GITHUB_REF') != 'refs/heads/master'):
        raise SystemExit('Use the serialized POS Windows cashier workflow on master')
    zip_name = Path(zip_path).name
    if not ZIP_NAME.fullmatch(zip_name) or int(zip_name[:-4].rsplit('-b', 1)[1]) != build:
        raise SystemExit(f'Zip name does not pin the build: {zip_name}')
    check_provenance(str(Path(zip_path).parent), build)
    installers = {
        'cashier-net8': verify_installer(net8_path, build),
        'cashier-net48': verify_installer(net48_path, build),
    }
    paths = {'cashier-net8': Path(net8_path), 'cashier-net48': Path(net48_path)}
    if installers['cashier-net8'] == installers['cashier-net48']:
        raise SystemExit('Installers must be distinct files')
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
        print(json.dumps({'build': build, 'assets': {k: str(v) for k, v in names.items()}}, indent=2))


if __name__ == '__main__':
    main()
