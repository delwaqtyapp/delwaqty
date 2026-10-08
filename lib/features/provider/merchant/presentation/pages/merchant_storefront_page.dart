import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

class StorefrontData {
  const StorefrontData({
    this.id = '',
    this.name = '',
    this.description,
    this.logoUrl,
    this.coverUrl,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
    this.deliveryFee,
    this.minOrder,
    this.deliveryTimeMin,
  });

  factory StorefrontData.fromRow(Map<String, dynamic> row) => StorefrontData(
        id: row['id'] as String? ?? '',
        name: row['name'] as String? ?? '',
        description: row['description'] as String?,
        logoUrl: row['logo_url'] as String?,
        coverUrl: row['cover_url'] as String?,
        phone: row['phone'] as String?,
        address: row['address'] as String?,
        latitude: (row['latitude'] as num?)?.toDouble(),
        longitude: (row['longitude'] as num?)?.toDouble(),
        deliveryFee: (row['delivery_fee'] as num?)?.toDouble(),
        minOrder: (row['min_order'] as num?)?.toDouble(),
        deliveryTimeMin: (row['delivery_time_min'] as num?)?.toInt(),
      );

  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;
  final String? phone;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? deliveryFee;
  final double? minOrder;
  final int? deliveryTimeMin;

}

/// One row of the weekly schedule.
class WorkingHoursDay {
  const WorkingHoursDay({
    required this.day,
    this.open = '09:00',
    this.close = '23:00',
    this.closed = true,
  });

  final int day;
  final String open;
  final String close;
  final bool closed;

  WorkingHoursDay copyWith({String? open, String? close, bool? closed}) =>
      WorkingHoursDay(
        day: day,
        open: open ?? this.open,
        close: close ?? this.close,
        closed: closed ?? this.closed,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'open': open,
        'close': close,
        'closed': closed,
      };
}

final storefrontProvider = FutureProvider<StorefrontData>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final merchantId = await ref.watch(providerMerchantIdProvider.future);
  if (merchantId.isEmpty) return const StorefrontData();
  final row = await client
      .from('merchants')
      .select(
        'id, name, description, logo_url, cover_url, phone, address, '
        'latitude, longitude, delivery_fee, min_order, delivery_time_min',
      )
      .eq('id', merchantId)
      .maybeSingle();
  if (row == null) return const StorefrontData();
  return StorefrontData.fromRow(row);
});

final workingHoursProvider =
    FutureProvider<List<WorkingHoursDay>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client.rpc('provider_get_availability');
  final schedule = (res as Map<String, dynamic>?)?['schedule'];
  if (schedule is! List) {
    return List.generate(7, (i) => WorkingHoursDay(day: i));
  }
  final byDay = <int, WorkingHoursDay>{};
  for (final raw in schedule) {
    final e = raw as Map<String, dynamic>;
    final day = (e['day_of_week'] as num?)?.toInt();
    if (day == null || day < 0 || day > 6) continue;
    byDay[day] = WorkingHoursDay(
      day: day,
      open: _hhmm(e['open_time']),
      close: _hhmm(e['close_time']),
      closed: (e['is_closed'] as bool?) ?? true,
    );
  }
  return List.generate(
    7,
    (i) => byDay[i] ?? WorkingHoursDay(day: i),
  );
});

String _hhmm(Object? value) {
  if (value is String && value.length >= 5) return value.substring(0, 5);
  return '09:00';
}

class StorefrontNotifier {
  StorefrontNotifier(this._ref);

  final Ref _ref;

  Future<void> save(StorefrontData data) async {
    final client = _ref.read(supabaseClientProvider);
    await client.rpc(
      'update_my_storefront',
      params: {
        'p_name': data.name,
        'p_description': data.description,
        'p_logo_url': data.logoUrl,
        'p_cover_url': data.coverUrl,
        'p_phone': data.phone,
        'p_address': data.address,
        'p_delivery_fee': data.deliveryFee,
        'p_min_order': data.minOrder,
        'p_delivery_time_min': data.deliveryTimeMin,
      },
    );
    _ref.invalidate(storefrontProvider);
  }

  Future<void> saveHours(List<WorkingHoursDay> days) async {
    final client = _ref.read(supabaseClientProvider);
    await client.rpc(
      'provider_set_working_hours',
      params: {
        'p_schedule': days.map((d) => d.toJson()).toList(),
      },
    );
    _ref.invalidate(workingHoursProvider);
  }
}

final storefrontNotifierProvider =
    Provider<StorefrontNotifier>(StorefrontNotifier.new);

/// Storefront editor: identity, contact, delivery policy and the weekly
/// opening hours.
///
/// `merchants_update_own` and the `working_hours` table both existed with
/// no writer, so the merchant could open/close the store but could never
/// change its name, fees or hours.
class MerchantStorefrontPage extends ConsumerStatefulWidget {
  const MerchantStorefrontPage({super.key});

  @override
  ConsumerState<MerchantStorefrontPage> createState() =>
      _MerchantStorefrontPageState();
}

class _MerchantStorefrontPageState
    extends ConsumerState<MerchantStorefrontPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _logoUrl = TextEditingController();
  final _deliveryFee = TextEditingController();
  final _minOrder = TextEditingController();
  final _deliveryTime = TextEditingController();

  List<WorkingHoursDay> _hours = List.generate(7, (i) => WorkingHoursDay(day: i));
  bool _hydrated = false;
  bool _saving = false;
  bool _hoursDirty = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _address.dispose();
    _logoUrl.dispose();
    _deliveryFee.dispose();
    _minOrder.dispose();
    _deliveryTime.dispose();
    super.dispose();
  }

  void _hydrate(StorefrontData data) {
    if (_hydrated) return;
    _hydrated = true;
    _name.text = data.name;
    _description.text = data.description ?? '';
    _phone.text = data.phone ?? '';
    _address.text = data.address ?? '';
    _logoUrl.text = data.logoUrl ?? '';
    _deliveryFee.text = data.deliveryFee == null ? '' : '${data.deliveryFee}';
    _minOrder.text = data.minOrder == null ? '' : '${data.minOrder}';
    _deliveryTime.text =
        data.deliveryTimeMin == null ? '' : '${data.deliveryTimeMin}';
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(storefrontNotifierProvider).save(
            StorefrontData(
              id: _hydrated ? '' : '',
              name: _name.text.trim(),
              description: _description.text.trim().isEmpty
                  ? null
                  : _description.text.trim(),
              logoUrl: _logoUrl.text.trim().isEmpty
                  ? null
                  : _logoUrl.text.trim(),
              phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
              address: _address.text.trim().isEmpty
                  ? null
                  : _address.text.trim(),
              deliveryFee: double.tryParse(_deliveryFee.text.trim()),
              minOrder: double.tryParse(_minOrder.text.trim()),
              deliveryTimeMin: int.tryParse(_deliveryTime.text.trim()),
            ),
          );
      if (_hoursDirty) {
        await ref
            .read(storefrontNotifierProvider)
            .saveHours(_hours);
        if (mounted) setState(() => _hoursDirty = false);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.updatedSuccessfully)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.somethingWentWrong)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final storefrontAsync = ref.watch(storefrontProvider);
    final hoursAsync = ref.watch(workingHoursProvider);

    storefrontAsync.whenData(_hydrate);
    if (!_hydrated && hoursAsync.hasValue) {
      _hours = hoursAsync.requireValue;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.storefront)),
      body: storefrontAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.failedToLoad)),
        data: (data) {
          if (data.id.isEmpty) {
            return Center(child: Text(l10n.noMerchantAccount));
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _SectionTitle(title: l10n.storeIdentity),
                _field(_name, l10n.storeName,
                    required: true),
                _field(_description, l10n.description, maxLines: 3),
                _field(_logoUrl, l10n.logoUrl, keyboard: TextInputType.url),
                const SizedBox(height: 16),
                _SectionTitle(title: l10n.contact),
                _field(_phone, l10n.phone, keyboard: TextInputType.phone),
                _field(_address, l10n.address, maxLines: 2),
                const SizedBox(height: 16),
                _SectionTitle(title: l10n.deliveryPolicy),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _deliveryFee,
                        l10n.deliveryFee,
                        keyboard: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        _minOrder,
                        l10n.minimumOrder,
                        keyboard: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                _field(
                  _deliveryTime,
                  l10n.deliveryTimeMinutes,
                  keyboard: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _SectionTitle(title: l10n.workingHours),
                if (hoursAsync.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  ..._buildHours(l10n),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(l10n.save),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildHours(AppLocalizations l10n) {
    final dayNames = [
      l10n.sunday,
      l10n.monday,
      l10n.tuesday,
      l10n.wednesday,
      l10n.thursday,
      l10n.friday,
      l10n.saturday,
    ];
    return [
      for (var i = 0; i < _hours.length; i++)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: SwitchListTile(
            value: !_hours[i].closed,
            title: Text(dayNames[_hours[i].day]),
            subtitle: _hours[i].closed
                ? null
                : Row(
                    children: [
                      Expanded(
                        child: _timeField(
                          value: _hours[i].open,
                          onChanged: (v) => setState(() {
                            _hours[i] = _hours[i].copyWith(open: v, closed: false);
                            _hoursDirty = true;
                          }),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('—'),
                      ),
                      Expanded(
                        child: _timeField(
                          value: _hours[i].close,
                          onChanged: (v) => setState(() {
                            _hours[i] = _hours[i].copyWith(close: v, closed: false);
                            _hoursDirty = true;
                          }),
                        ),
                      ),
                    ],
                  ),
            onChanged: (open) => setState(() {
              _hours[i] = _hours[i].copyWith(closed: !open);
              _hoursDirty = true;
            }),
          ),
        ),
    ];
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                ? AppLocalizations.of(context).fieldRequired
                : null
            : null,
      ),
    );
  }

  Widget _timeField({required String value, required ValueChanged<String> onChanged}) {
    return TextFormField(
      initialValue: value,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      onChanged: onChanged,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.brandPurple,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}