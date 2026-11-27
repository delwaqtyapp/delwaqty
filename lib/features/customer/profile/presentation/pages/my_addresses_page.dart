import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/customer/location/presentation/widgets/smart_map_picker_sheet.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// The signed-in user's saved delivery addresses (user_addresses). Row-level
/// security limits every read and write to the owner's own rows.
final myAddressesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return const <Map<String, dynamic>>[];
      final rows = await client
          .from('user_addresses')
          .select('id,label,address,latitude,longitude,is_default')
          .eq('user_id', uid)
          .order('is_default', ascending: false)
          .order('created_at');
      return (rows as List<dynamic>).cast<Map<String, dynamic>>();
    });

class MyAddressesPage extends ConsumerWidget {
  const MyAddressesPage({super.key});

  Future<String?> _askLabel(
    BuildContext context,
    AppLocalizations l10n, {
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addressLabelHint),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(hintText: l10n.addressLabelHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String okMessage,
  ) async {
    try {
      await action();
      ref.invalidate(myAddressesProvider);
      if (context.mounted) context.showAppSnackBar(okMessage);
    } catch (e) {
      if (context.mounted) {
        context.showAppSnackBar(appErrorText(context, e), isError: true);
      }
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final picked = await SmartMapPickerSheet.show(context);
    if (picked == null || !context.mounted) return;
    final label = await _askLabel(context, l10n);
    if (label == null || !context.mounted) return;
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    final isFirst = (ref.read(myAddressesProvider).value ?? const []).isEmpty;
    await _run(context, ref, () async {
      await client.from('user_addresses').insert({
        'user_id': uid,
        'label': label,
        'address': picked.detailedAddress,
        'latitude': picked.latitude,
        'longitude': picked.longitude,
        'is_default': isFirst,
      });
    }, l10n.addressSaved);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> a,
  ) async {
    final l10n = AppLocalizations.of(context);
    final label = await _askLabel(
      context,
      l10n,
      initial: a['label'] as String? ?? '',
    );
    if (label == null || !context.mounted) return;
    await _run(context, ref, () async {
      await Supabase.instance.client
          .from('user_addresses')
          .update({'label': label})
          .eq('id', a['id'] as String);
    }, l10n.addressUpdated);
  }

  Future<void> _makeDefault(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> a,
  ) async {
    final l10n = AppLocalizations.of(context);
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    await _run(context, ref, () async {
      await client
          .from('user_addresses')
          .update({'is_default': false})
          .eq('user_id', uid);
      await client
          .from('user_addresses')
          .update({'is_default': true})
          .eq('id', a['id'] as String);
    }, l10n.addressUpdated);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> a,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.deleteAddressConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, ref, () async {
      await Supabase.instance.client
          .from('user_addresses')
          .delete()
          .eq('id', a['id'] as String);
    }, l10n.addressDeleted);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(myAddressesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myAddresses)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: Text(l10n.addAddress),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(appErrorText(context, e))),
          data: (rows) {
            if (rows.isEmpty) {
              return Center(child: Text(l10n.noSavedAddresses));
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final a = rows[i];
                final isDefault = a['is_default'] == true;
                final label = (a['label'] as String?)?.trim() ?? '';
                return Card(
                  child: ListTile(
                    leading: Icon(
                      isDefault
                          ? Icons.home_rounded
                          : Icons.location_on_outlined,
                      color: isDefault ? cs.primary : null,
                    ),
                    title: Text(
                      label.isEmpty ? (a['address'] as String? ?? '') : label,
                    ),
                    subtitle: Text(
                      [
                        if (isDefault) l10n.defaultAddressBadge,
                        if (label.isNotEmpty) a['address'] as String? ?? '',
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        switch (v) {
                          case 'rename':
                            _rename(context, ref, a);
                          case 'default':
                            _makeDefault(context, ref, a);
                          case 'delete':
                            _delete(context, ref, a);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'rename', child: Text(l10n.edit)),
                        if (!isDefault)
                          PopupMenuItem(
                            value: 'default',
                            child: Text(l10n.setAsDefaultAddress),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
