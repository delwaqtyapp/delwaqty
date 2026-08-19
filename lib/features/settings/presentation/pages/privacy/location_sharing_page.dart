import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';

class LocationSharingPage extends StatefulWidget {
  const LocationSharingPage({super.key});

  @override
  State<LocationSharingPage> createState() => _LocationSharingPageState();
}

class _LocationSharingPageState extends State<LocationSharingPage> {
  late final SharedPreferences _prefs;
  bool _shareWithDrivers = true;
  bool _shareWithMerchants = true;
  bool _backgroundLocation = false;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _shareWithDrivers = _prefs.getBool(StorageKeys.shareWithDrivers) ?? true;
    _shareWithMerchants = _prefs.getBool(StorageKeys.shareWithMerchants) ?? true;
    _backgroundLocation = _prefs.getBool(StorageKeys.backgroundLocation) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.locationSharing),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.directions_car_outlined),
            title: Text(l10n.shareWithDriver),
            subtitle: Text(l10n.shareWithDriverDescription),
            value: _shareWithDrivers,
            onChanged: (v) async {
              setState(() => _shareWithDrivers = v);
              await _prefs.setBool(StorageKeys.shareWithDrivers, v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.store_outlined),
            title: Text(l10n.shareWithMerchant),
            subtitle: Text(l10n.shareWithMerchantDescription),
            value: _shareWithMerchants,
            onChanged: (v) async {
              setState(() => _shareWithMerchants = v);
              await _prefs.setBool(StorageKeys.shareWithMerchants, v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.my_location_outlined),
            title: Text(l10n.backgroundLocation),
            subtitle: Text(l10n.backgroundLocationDescription),
            value: _backgroundLocation,
            onChanged: (v) async {
              setState(() => _backgroundLocation = v);
              await _prefs.setBool(StorageKeys.backgroundLocation, v);
              if (v) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.backgroundLocationEnabled)),
              );
            },
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.locationPrivacyNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}