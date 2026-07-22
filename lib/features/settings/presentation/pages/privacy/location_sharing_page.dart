import 'package:flutter/material.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class LocationSharingPage extends StatefulWidget {
  const LocationSharingPage({super.key});

  @override
  State<LocationSharingPage> createState() => _LocationSharingPageState();
}

class _LocationSharingPageState extends State<LocationSharingPage> {
  bool _shareWithDrivers = true;
  bool _shareWithMerchants = true;
  bool _backgroundLocation = false;

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
            onChanged: (v) => setState(() => _shareWithDrivers = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.store_outlined),
            title: Text(l10n.shareWithMerchant),
            subtitle: Text(l10n.shareWithMerchantDescription),
            value: _shareWithMerchants,
            onChanged: (v) => setState(() => _shareWithMerchants = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.my_location_outlined),
            title: Text(l10n.backgroundLocation),
            subtitle: Text(l10n.backgroundLocationDescription),
            value: _backgroundLocation,
            onChanged: (v) {
              setState(() => _backgroundLocation = v);
              if (v) context.showAppSnackBar(l10n.backgroundLocationEnabled);
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
