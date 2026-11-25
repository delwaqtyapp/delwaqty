import subprocess
from pathlib import Path
import unittest
from unittest.mock import patch

import publish_development as publisher


class PublisherSafetyTest(unittest.TestCase):
    def manifest(self, build):
        return {'channels': {f: {'version': build} for f in publisher.FLAVORS}}

    def test_requires_increasing_code_above_previous_latest(self):
        for value in (6, 7):
            with self.assertRaises(SystemExit):
                publisher.validate_floor(value, self.manifest(7))
        publisher.validate_floor(8, self.manifest(7))

    def test_one_higher_channel_blocks_downgrade(self):
        manifest = self.manifest(7)
        manifest['channels']['driver']['version'] = 9
        with self.assertRaises(SystemExit):
            publisher.validate_floor(8, manifest)

    def test_missing_channel_cannot_hide_a_floor(self):
        with self.assertRaises(SystemExit):
            publisher.validate_floor(8, {'channels': {}})

    def test_unknown_channels_do_not_block_the_floor_check(self):
        manifest = self.manifest(7)
        manifest['channels']['cashier-net8'] = {'version': 999}
        publisher.validate_floor(8, manifest)  # cashier uses a different counter

    def test_merge_preserves_unknown_channels_and_top_level_keys(self):
        old = self.manifest(7)
        old['channels']['cashier-net8'] = {'version': 42, 'apk': 'x.exe', 'sha256': 'a' * 64}
        old['other'] = {'kept': True}
        merged = publisher.build_manifest(old, 'sha123', {
            f: {'version': 8, 'versionName': '1.0.0', 'apk': f'{f}.apk'}
            for f in publisher.FLAVORS
        })
        self.assertEqual(merged['channels']['cashier-net8']['version'], 42)
        self.assertEqual(merged['other'], {'kept': True})
        self.assertEqual(merged['channels']['customer']['version'], 8)
        self.assertEqual(merged['sourceCommit'], 'sha123')
        self.assertEqual(old['channels']['customer']['version'], 7)  # input untouched

    def test_exact_retry_rebuilds_an_identical_manifest(self):
        old = self.manifest(8)
        old['sourceCommit'] = 'sha123'
        entries = {f: dict(old['channels'][f]) for f in publisher.FLAVORS}
        self.assertEqual(old, publisher.build_manifest(old, 'sha123', entries))

    def test_same_build_only_allowed_for_exact_payload_retry(self):
        publisher.validate_floor(8, self.manifest(8), allow_same=True)
        with self.assertRaises(SystemExit):
            publisher.validate_floor(7, self.manifest(8), allow_same=True)

    @patch.object(publisher.subprocess, 'run')
    def test_apksigner_verifies_bytes_before_fingerprint(self, run):
        run.return_value.stdout = f'Signer #1 certificate SHA-256 digest: {publisher.SIGNER}\n'
        publisher.verify_apk(Path('signed.apk'), '/sdk/apksigner')
        run.assert_called_once_with(
            ['/sdk/apksigner', 'verify', '--verbose', '--print-certs', 'signed.apk'],
            text=True, capture_output=True, check=True,
        )

    @patch.object(publisher.subprocess, 'run')
    def test_malformed_or_tampered_apk_rejected_even_with_certificate(self, run):
        run.side_effect = subprocess.CalledProcessError(
            1, ['apksigner'], output=f'Signer #1 certificate SHA-256 digest: {publisher.SIGNER}',
        )
        with self.assertRaises(subprocess.CalledProcessError):
            publisher.verify_apk(Path('forged.apk'), 'apksigner')

    @patch.object(publisher.subprocess, 'run')
    def test_additional_unapproved_signer_rejected(self, run):
        run.return_value.stdout = (
            f'Signer #1 certificate SHA-256 digest: {publisher.SIGNER}\n'
            f'Signer #2 certificate SHA-256 digest: {"b" * 64}\n'
        )
        with self.assertRaises(SystemExit):
            publisher.verify_apk(Path('multi.apk'), 'apksigner')

    @patch.object(publisher.subprocess, 'run')
    def test_no_verified_signer_rejected(self, run):
        run.return_value.stdout = 'No verified certificate'
        with self.assertRaises(SystemExit):
            publisher.verify_apk(Path('unsigned.apk'), 'apksigner')

    def test_no_asset_deletion_or_apk_clobber_path(self):
        source = Path(publisher.__file__).read_text()
        self.assertNotIn('delete-asset', source)
        self.assertIn("str(manifest_path), '--clobber'", source)
        self.assertNotIn("str(apk), '--clobber'", source)

    def test_publishers_are_serialized_by_workflow(self):
        workflow = Path('.github/workflows/publish-development.yml').read_text()
        self.assertIn('group: delwaqty-development-publisher', workflow)
        self.assertIn('cancel-in-progress: false', workflow)
        self.assertIn('GITHUB_WORKFLOW_REF', Path(publisher.__file__).read_text())

    def test_no_unverifiable_one_off_reuse_exception(self):
        source = Path(publisher.__file__).read_text()
        self.assertNotIn('REUSE_', source)
        self.assertIn("CI run must be for the current master commit", source)


if __name__ == '__main__':
    unittest.main()
