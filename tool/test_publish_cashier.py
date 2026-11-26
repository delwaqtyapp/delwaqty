import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import publish_cashier as cashier

SHA = 'a' * 40


class CashierPublisherTest(unittest.TestCase):
    def make_build(self, temp, build=12):
        root = Path(temp)
        files = {
            'zip': root / f'delwaqty-cashier-windows-b{build}.zip',
            'n8': root / f'delwaqty-cashier-setup-net8-b{build}.exe',
            'n48': root / f'delwaqty-cashier-setup-net48-b{build}.exe',
        }
        for i, f in enumerate(files.values()):
            f.write_bytes(b'payload-%d' % i)
        (root / 'build-provenance.json').write_text(json.dumps(
            {'run_id': '777', 'run_number': build, 'sha': SHA}))
        return files

    ENV = {'GITHUB_ACTIONS': 'true', 'GITHUB_REF': 'refs/heads/master',
           'GITHUB_RUN_ID': '777', 'BUILD_SHA': SHA,
           'GITHUB_WORKFLOW_REF': cashier.WORKFLOW}

    def run_main(self, files, build=12, existing=()):
        calls = []

        def fake_gh(*args):
            calls.append(args)
            if args[:2] == ('release', 'view'):
                return json.dumps({'assets': [{'name': n} for n in existing]})
            if args[:2] == ('release', 'download'):
                name = args[args.index('-p') + 1]
                out = Path(args[args.index('-D') + 1])
                src = next(f for f in files.values() if f.name == name)
                (out / name).write_bytes(src.read_bytes())
            return ''

        argv = ['publish_cashier.py', str(build), str(files['zip']), str(files['n8']), str(files['n48'])]
        with patch.object(cashier, 'gh', side_effect=fake_gh), \
                patch.dict(os.environ, self.ENV), patch.object(os.sys, 'argv', argv):
            cashier.main()
        return calls

    def test_uploads_three_assets_and_never_touches_versions_json(self):
        with tempfile.TemporaryDirectory() as t:
            calls = self.run_main(self.make_build(t))
            flat = ' '.join(' '.join(map(str, c)) for c in calls)
            self.assertNotIn('versions.json', flat)
            self.assertEqual(sum(1 for c in calls if c[:2] == ('release', 'upload')), 3)
            self.assertNotIn('--clobber', [a for c in calls if c[:2] == ('release', 'upload') for a in c])

    def test_existing_asset_is_reproven_not_reuploaded(self):
        with tempfile.TemporaryDirectory() as t:
            files = self.make_build(t)
            calls = self.run_main(files, existing={files['zip'].name})
            self.assertEqual(sum(1 for c in calls if c[:2] == ('release', 'upload')), 2)

    def test_refuses_outside_master_workflow(self):
        with tempfile.TemporaryDirectory() as t:
            files = self.make_build(t)
            for key, val in (('GITHUB_REF', 'refs/heads/other'), ('GITHUB_ACTIONS', 'false')):
                env = dict(self.ENV, **{key: val})
                argv = ['p', '12', str(files['zip']), str(files['n8']), str(files['n48'])]
                with patch.dict(os.environ, env), patch.object(os.sys, 'argv', argv), \
                        patch.object(cashier, 'gh') as gh:
                    with self.assertRaises(SystemExit):
                        cashier.main()
                    gh.assert_not_called()

    def test_refuses_wrong_build_number_in_name(self):
        with tempfile.TemporaryDirectory() as t:
            files = self.make_build(t, build=11)
            with self.assertRaises(SystemExit):
                self.run_main(files, build=12)

    def test_refuses_provenance_mismatch(self):
        with tempfile.TemporaryDirectory() as t:
            files = self.make_build(t)
            (Path(t) / 'build-provenance.json').write_text(json.dumps(
                {'run_id': '999', 'run_number': 12, 'sha': SHA}))
            with self.assertRaises(SystemExit):
                self.run_main(files)

    def test_refuses_empty_installer(self):
        with tempfile.TemporaryDirectory() as t:
            files = self.make_build(t)
            files['n8'].write_bytes(b'')
            with self.assertRaises(SystemExit):
                self.run_main(files)


if __name__ == '__main__':
    unittest.main()
