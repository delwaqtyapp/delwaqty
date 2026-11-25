import json
import subprocess
from pathlib import Path
import unittest
from unittest.mock import patch

import publish_cashier as cashier


def flutter_manifest():
    return {
        'sourceCommit': 'abc',
        'channels': {
            f: {'version': 8, 'versionName': '1.0.0', 'apk': f'delwaqty-{f}-8.apk',
                'notes': 'x', 'sha256': 'a' * 64}
            for f in ('customer', 'admin', 'driver', 'provider')
        },
    }


class CashierPublisherSafetyTest(unittest.TestCase):
    def test_fetch_manifest_fails_closed_on_download_error(self):
        with patch.object(cashier, 'gh', side_effect=subprocess.CalledProcessError(1, 'gh')):
            with self.assertRaises(SystemExit):
                cashier.fetch_manifest('/tmp')

    def test_fetch_manifest_fails_closed_on_bad_json(self):
        import tempfile
        with tempfile.TemporaryDirectory() as temp:
            (Path(temp) / 'versions.json').write_text('not json')
            with patch.object(cashier, 'gh'):
                with self.assertRaises(SystemExit):
                    cashier.fetch_manifest(temp)

    def test_schema_rejects_missing_channels_and_bad_versions(self):
        with self.assertRaises(SystemExit):
            cashier.validate_manifest({'channels': {}})
        bad = flutter_manifest()
        bad['channels']['customer']['version'] = 'eight'
        with self.assertRaises(SystemExit):
            cashier.validate_manifest(bad)
        bad2 = flutter_manifest()
        bad2['channels']['customer']['sha256'] = 'zz'
        with self.assertRaises(SystemExit):
            cashier.validate_manifest(bad2)
        empty = flutter_manifest()
        empty['channels'] = {}
        with self.assertRaises(SystemExit):
            cashier.validate_manifest(empty)

    def test_merge_preserves_flutter_channels_and_top_level_keys(self):
        manifest = flutter_manifest()
        merged = cashier.merge(manifest, 12, {
            'cashier-net8': ('delwaqty-cashier-setup-net8-b12.exe', 'b' * 64),
            'cashier-net48': ('delwaqty-cashier-setup-net48-b12.exe', 'c' * 64),
        })
        for flavor in ('customer', 'admin', 'driver', 'provider'):
            self.assertEqual(merged['channels'][flavor], manifest['channels'][flavor])
        self.assertEqual(merged['sourceCommit'], 'abc')
        self.assertEqual(merged['channels']['cashier-net8']['version'], 12)
        self.assertEqual(merged['channels']['cashier-net8']['sha256'], 'b' * 64)
        self.assertEqual(merged['channels']['cashier-net48']['apk'],
                         'delwaqty-cashier-setup-net48-b12.exe')
        self.assertNotIn('cashier-net8', manifest['channels'])  # input untouched

    def test_monotonic_refuses_same_or_lower_build(self):
        manifest = flutter_manifest()
        manifest['channels']['cashier-net8'] = {'version': 12}
        cashier.check_monotonic(manifest, 13)
        with self.assertRaises(SystemExit):
            cashier.check_monotonic(manifest, 12)
        with self.assertRaises(SystemExit):
            cashier.check_monotonic(manifest, 5)

    def test_installer_names_pin_runtime_and_build(self):
        import tempfile
        with tempfile.TemporaryDirectory() as temp:
            good = Path(temp) / 'delwaqty-cashier-setup-net8-b12.exe'
            good.write_bytes(b'installer')
            self.assertEqual(cashier.verify_installer(good, 12), good.name)
            wrong_build = Path(temp) / 'delwaqty-cashier-setup-net8-b13.exe'
            wrong_build.write_bytes(b'installer')
            with self.assertRaises(SystemExit):
                cashier.verify_installer(wrong_build, 12)
            rolling = Path(temp) / 'delwaqty-cashier-setup-net8-EXPERIMENTAL.exe'
            rolling.write_bytes(b'installer')
            with self.assertRaises(SystemExit):
                cashier.verify_installer(rolling, 12)

    def test_no_empty_manifest_fallback_and_no_clobbered_installers(self):
        source = Path(cashier.__file__).read_text()
        self.assertNotIn("echo '{\"channels\":{}}'", source)
        self.assertNotIn("or echo", source)
        # Only the manifest upload may clobber; installer assets never.
        self.assertIn("str(merged_path), '--clobber'", source)
        for line in source.splitlines():
            if '--clobber' in line and "'upload'" in line:
                self.assertIn('merged_path', line)

    def test_publishers_share_the_serialization_lock(self):
        pos = Path('.github/workflows/pos-windows.yml').read_text()
        flutter = Path('.github/workflows/publish-development.yml').read_text()
        for workflow in (pos, flutter):
            self.assertIn('group: delwaqty-development-publisher', workflow)
            self.assertIn('cancel-in-progress: false', workflow)


if __name__ == '__main__':
    unittest.main()
