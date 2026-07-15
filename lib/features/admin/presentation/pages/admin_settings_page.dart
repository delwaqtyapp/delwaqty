import 'package:flutter/material.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Settings'),
      ),
      body: ListView(
        children: [
          _SettingsSection(
            title: 'General',
            children: [
              SwitchListTile(
                title: const Text('Maintenance Mode'),
                subtitle: const Text('Temporarily disable the platform'),
                value: false,
                onChanged: (_) {},
              ),
              SwitchListTile(
                title: const Text('New Registrations'),
                subtitle: const Text('Allow new user registrations'),
                value: true,
                onChanged: (_) {},
              ),
              SwitchListTile(
                title: const Text('New Merchant Applications'),
                subtitle: const Text('Allow new merchant sign-ups'),
                value: true,
                onChanged: (_) {},
              ),
            ],
          ),
          _SettingsSection(
            title: 'Orders',
            children: [
              SwitchListTile(
                title: const Text('Auto-assign Drivers'),
                subtitle: const Text('Automatically assign nearest driver'),
                value: true,
                onChanged: (_) {},
              ),
              SwitchListTile(
                title: const Text('Allow Cancellations'),
                subtitle: const Text('Allow customers to cancel orders'),
                value: true,
                onChanged: (_) {},
              ),
            ],
          ),
          _SettingsSection(
            title: 'Payments',
            children: [
              SwitchListTile(
                title: const Text('Cash on Delivery'),
                subtitle: const Text('Accept cash payments on delivery'),
                value: true,
                onChanged: (_) {},
              ),
              SwitchListTile(
                title: const Text('Auto Payouts'),
                subtitle: const Text('Process merchant payouts automatically'),
                value: false,
                onChanged: (_) {},
              ),
            ],
          ),
          _SettingsSection(
            title: 'Notifications',
            children: [
              SwitchListTile(
                title: const Text('System-wide Announcements'),
                subtitle: const Text('Push notifications to all users'),
                value: true,
                onChanged: (_) {},
              ),
              SwitchListTile(
                title: const Text('Admin Alerts'),
                subtitle: const Text('Receive critical system alerts'),
                value: true,
                onChanged: (_) {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }
}
