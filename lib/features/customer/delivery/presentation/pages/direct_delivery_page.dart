import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/features/customer/location/presentation/widgets/smart_map_picker_sheet.dart';
import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/features/customer/search/domain/entities/geo_point.dart';
import 'package:delwaqty/features/customer/search/domain/entities/place_suggestion.dart';
import 'package:delwaqty/features/customer/search/domain/entities/search_session.dart';
import 'package:delwaqty/features/customer/search/presentation/providers/search_providers.dart';

import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/customer/delivery/domain/direct_delivery_validation.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

/// Saved delivery addresses (user_addresses) for the quick-pick chips.
final _directSavedAddressesProvider =
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

class DirectDeliveryPage extends ConsumerStatefulWidget {
  const DirectDeliveryPage({super.key});

  @override
  ConsumerState<DirectDeliveryPage> createState() => _DirectDeliveryPageState();
}

class _DirectDeliveryPageState extends ConsumerState<DirectDeliveryPage> {
  final _dropoffController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _placeDescController = TextEditingController();
  final _phoneController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _itemQtyController = TextEditingController(text: '1');
  final _qtyFocusNode = FocusNode();

  final List<_ShoppingItem> _items = [];
  bool _saveNumber = true;
  bool _loadingLocation = false;
  bool _submitting = false;
  double? _estimateFee;
  String _estimateCurrency = 'EGP';
  int _estimateSeq = 0;
  double? _pickedDropoffLat;
  double? _pickedDropoffLng;

  String _selectedUnit = 'none';
  String _selectedWeight = 'none';
  String _selectedPieceUnit = 'none';

  static const _savedPhoneKey = 'direct_delivery_saved_phone';

  @override
  void initState() {
    super.initState();
    unawaited(_loadPhoneNumber());
    _qtyFocusNode.addListener(() {
      if (_qtyFocusNode.hasFocus) {
        _itemQtyController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _itemQtyController.text.length,
        );
      }
    });
  }

  Future<void> _loadPhoneNumber() async {
    final authState = ref.read(authStateProvider);
    if (authState is AuthAuthenticated && authState.user.phone != null) {
      _phoneController.text = authState.user.phone!;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_savedPhoneKey);
    if (mounted &&
        _phoneController.text.isEmpty &&
        saved != null &&
        saved.isNotEmpty) {
      _phoneController.text = saved;
    }
  }

  @override
  void dispose() {
    _dropoffController.dispose();
    _descriptionController.dispose();
    _placeDescController.dispose();
    _phoneController.dispose();
    _itemNameController.dispose();
    _itemQtyController.dispose();
    _qtyFocusNode.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _itemNameController.text.trim();
    final qty = parseItemQuantity(_itemQtyController.text);
    if (name.isEmpty) return;
    if (qty == null) {
      context.showAppSnackBar(
        AppLocalizations.of(context).directDeliveryErrQuantity,
        isError: true,
      );
      return;
    }

    String? subUnit;
    if (_selectedUnit == 'kg') {
      subUnit = _selectedWeight;
    } else if (_selectedUnit == 'piece') {
      subUnit = _selectedPieceUnit;
    }

    setState(() {
      _items.add(
        _ShoppingItem(
          name: name,
          quantity: qty,
          unit: _selectedUnit,
          subUnit: subUnit,
        ),
      );
      _itemNameController.clear();
      _itemQtyController.text = '1';
      _selectedUnit = 'none';
      _selectedWeight = 'none';
      _selectedPieceUnit = 'none';
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _clearPin() {
    _pickedDropoffLat = null;
    _pickedDropoffLng = null;
    if (_estimateFee != null) setState(() => _estimateFee = null);
  }

  /// Fee estimate for the chosen pin, from the server pricing table. Distance
  /// is straight-line, so the UI labels it an estimate.
  Future<void> _updateEstimate() async {
    final lat = _pickedDropoffLat;
    final lng = _pickedDropoffLng;
    final from = ref.read(userLocationProvider).value;
    if (lat == null || lng == null || from == null) return;
    final seq = ++_estimateSeq;
    try {
      final km =
          Geolocator.distanceBetween(from.latitude, from.longitude, lat, lng) /
          1000;
      final res = await ref
          .read(deliveryRepositoryProvider)
          .estimateDeliveryFee('courier', km);
      if (!mounted || seq != _estimateSeq) return;
      final fee = (res['fee'] as num?)?.toDouble();
      if (res['success'] == true && fee != null) {
        setState(() {
          _estimateFee = fee;
          _estimateCurrency = res['currency'] as String? ?? 'EGP';
        });
      }
    } catch (e, st) {
      // The estimate is informational; never block the request on it.
      ref.read(loggerProvider).e('Fee estimate failed', e, st);
    }
  }

  void _setPin(String address, double lat, double lng) {
    setState(() {
      _dropoffController.text = address;
      _pickedDropoffLat = lat;
      _pickedDropoffLng = lng;
      _estimateFee = null;
    });
    unawaited(_updateEstimate());
  }

  /// Lets the user choose among the geocoder's matches instead of silently
  /// taking the first one. Returns the chosen suggestion or null.
  Future<PlaceSuggestion?> _chooseSuggestion(
    List<PlaceSuggestion> suggestions,
    AppLocalizations l10n,
  ) {
    return showModalBottomSheet<PlaceSuggestion>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l10n.directDeliveryPickAddress,
                style: AppTextStyles.titleMedium,
              ),
            ),
            for (final s in suggestions.take(5))
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(s.primaryText),
                subtitle: s.secondaryText.isEmpty
                    ? null
                    : Text(s.secondaryText),
                onTap: () => Navigator.of(ctx).pop(s),
              ),
          ],
        ),
      ),
    );
  }

  String _errorText(DirectDeliveryError e, AppLocalizations l10n) =>
      switch (e) {
        DirectDeliveryError.noDropoff => l10n.directDeliveryErrAddress,
        DirectDeliveryError.noPhone => l10n.directDeliveryErrPhone,
        DirectDeliveryError.badPhone => l10n.directDeliveryErrPhoneInvalid,
        DirectDeliveryError.nothingToDeliver => l10n.directDeliveryErrNothing,
      };

  Future<void> _useCurrentLocation() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loadingLocation = true);
    try {
      final loc = ref.read(userLocationProvider.notifier);
      final value = await loc.refreshDeepLocked();
      if (value != null && mounted) {
        final address = value.detailedAddress.isNotEmpty
            ? value.detailedAddress
            : '${value.latitude}, ${value.longitude}';
        _setPin(address, value.latitude, value.longitude);
        final accuracy = value.accuracyMeters;
        if (accuracy != null && accuracy > precisionTargetMeters) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.accuracyInsufficient),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.locationError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _pickDropoffOnMap() async {
    final picked = await SmartMapPickerSheet.show(
      context,
      initialLat: _pickedDropoffLat,
      initialLng: _pickedDropoffLng,
    );
    if (picked != null && mounted) {
      _setPin(picked.detailedAddress, picked.latitude, picked.longitude);
    }
  }

  Future<void> _submitRequest() async {
    final l10n = AppLocalizations.of(context);
    final dropoffText = _dropoffController.text.trim();
    final phone = _phoneController.text.trim();
    final problem = validateDirectDelivery(
      dropoffText: dropoffText,
      phone: phone,
      itemCount: _items.length,
      description: _descriptionController.text,
    );
    if (problem != null) {
      context.showAppSnackBar(_errorText(problem, l10n), isError: true);
      return;
    }
    final authState = ref.read(authStateProvider);
    if (authState is! AuthAuthenticated) {
      context.showAppSnackBar(l10n.loginRequired, isError: true);
      return;
    }
    final location = ref.read(userLocationProvider).value;
    if (location == null) {
      context.showAppSnackBar(l10n.locationError, isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      double dropoffLat;
      double dropoffLng;
      String dropoffAddress;

      if (_pickedDropoffLat != null && _pickedDropoffLng != null) {
        dropoffLat = _pickedDropoffLat!;
        dropoffLng = _pickedDropoffLng!;
        dropoffAddress = dropoffText;
      } else {
        final places = ref.read(placesRepositoryProvider);
        final languageCode = ref.read(searchLanguageProvider);
        final session = SearchSession.generate();
        final suggestions = await places.autocomplete(
          query: dropoffText,
          languageCode: languageCode,
          origin: GeoPoint(location.latitude, location.longitude),
          session: session,
        );
        if (suggestions.isEmpty) {
          if (mounted) {
            context.showAppSnackBar(
              l10n.deliveryAddressNotFound,
              isError: true,
            );
          }
          return;
        }
        if (!mounted) return;
        final chosen = await _chooseSuggestion(suggestions, l10n);
        if (chosen == null || !mounted) return;
        final details = await places.details(
          placeId: chosen.placeId,
          languageCode: languageCode,
          session: session,
        );
        dropoffLat = details.location.latitude;
        dropoffLng = details.location.longitude;
        dropoffAddress = details.formattedAddress;
      }

      final itemsSummary = _items.isEmpty
          ? null
          : _items.map((i) => '${i.name} x${i.quantity}').join(', ');
      final notes = [
        if (_descriptionController.text.trim().isNotEmpty)
          _descriptionController.text.trim(),
        if (_placeDescController.text.trim().isNotEmpty)
          _placeDescController.text.trim(),
        phone,
      ].join(' | ');

      final deliveryId = await ref
          .read(deliveryRepositoryProvider)
          .requestCourierDelivery(
            riderId: authState.user.id,
            pickupLatitude: location.latitude,
            pickupLongitude: location.longitude,
            pickupAddress: location.detailedAddress,
            dropoffLatitude: dropoffLat,
            dropoffLongitude: dropoffLng,
            dropoffAddress: dropoffAddress,
            itemsSummary: itemsSummary,
            notes: notes,
          );
      try {
        await ref.read(deliveryRepositoryProvider).dispatchDelivery(deliveryId);
      } catch (e, st) {
        // The ride was created; driver matching can be retried from tracking.
        ref
            .read(loggerProvider)
            .e('Failed to dispatch delivery $deliveryId', e, st);
      }
      if (!mounted) return;
      if (_saveNumber) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_savedPhoneKey, phone);
        if (!mounted) return;
        context.showAppSnackBar(l10n.numberSaved);
      }
      unawaited(context.push('/delivery-tracking/$deliveryId'));
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(appErrorText(context, e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _itemDisplayText(_ShoppingItem item, AppLocalizations l10n) {
    if (item.unit == 'kg' && item.subUnit != null && item.subUnit != 'none') {
      final label = switch (item.subUnit) {
        'eighth' => l10n.weightEighth,
        'quarter' => l10n.weightQuarter,
        'third' => l10n.weightThird,
        'half' => l10n.weightHalf,
        'three_quarters' => l10n.weightThreeQuarters,
        'fifth' => l10n.weightFifth,
        'bundle' => l10n.weightBundle,
        _ => l10n.unitKg,
      };
      return '${item.quantity} $label';
    }
    if (item.unit == 'piece' &&
        item.subUnit != null &&
        item.subUnit != 'none') {
      final label = switch (item.subUnit) {
        'box' => l10n.pieceUnitBox,
        'carton' => l10n.pieceUnitCarton,
        'liter' => l10n.pieceUnitLiter,
        _ => l10n.unitPiece,
      };
      return '${item.quantity} $label';
    }
    if (item.unit == 'kg') return '${item.quantity} ${l10n.unitKg}';
    if (item.unit == 'piece') return '${item.quantity} ${l10n.unitPiece}';
    return '${item.quantity}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.directDelivery)),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildShoppingListSection(context, l10n, cs),
                  const SizedBox(height: 12),

                  _buildField(
                    context: context,
                    controller: _descriptionController,
                    label: l10n.describeYourOrder,
                    icon: Icons.description_outlined,
                    color: cs.tertiary,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  _buildDeliverToField(context, l10n, cs),
                  _buildSavedAddresses(l10n),
                  _buildEstimate(l10n, cs),
                  const SizedBox(height: 16),

                  _buildField(
                    context: context,
                    controller: _placeDescController,
                    label: l10n.placeDescription,
                    icon: Icons.info_outline_rounded,
                    color: AppColors.orderReady,
                    hint: l10n.placeDescriptionHint,
                  ),
                  const SizedBox(height: 16),

                  _buildPhoneSection(context, l10n, cs),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submitRequest,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              l10n.requestDelivery,
                              style: AppTextStyles.titleMedium,
                            ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedAddresses(AppLocalizations l10n) {
    final saved = ref.watch(_directSavedAddressesProvider).value;
    if (saved == null || saved.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            l10n.directDeliverySavedAddresses,
            style: AppTextStyles.bodySmall,
          ),
          for (final a in saved)
            if (a['latitude'] != null && a['longitude'] != null)
              ActionChip(
                avatar: const Icon(Icons.bookmark_outline_rounded, size: 16),
                label: Text(
                  (a['label'] as String?)?.trim().isNotEmpty == true
                      ? a['label'] as String
                      : (a['address'] as String? ?? ''),
                ),
                onPressed: () => _setPin(
                  a['address'] as String? ?? '',
                  (a['latitude'] as num).toDouble(),
                  (a['longitude'] as num).toDouble(),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildEstimate(AppLocalizations l10n, ColorScheme cs) {
    final fee = _estimateFee;
    if (fee == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${l10n.directDeliveryEstimateLabel}: '
              '${fee.toStringAsFixed(2)} $_estimateCurrency\n'
              '${l10n.directDeliveryEstimateNote}',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverToField(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _dropoffController,
        onChanged: (_) => _clearPin(),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.location_on_outlined, color: cs.error),
          labelText: l10n.deliverTo,
          labelStyle: AppTextStyles.bodyMedium.copyWith(color: cs.error),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          suffixIcon: _loadingLocation
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _pickDropoffOnMap,
                      icon: const Icon(
                        Icons.edit_location_alt_rounded,
                        size: 20,
                      ),
                      tooltip: l10n.pickLocationOnMap,
                      color: cs.primary,
                    ),
                    IconButton(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.my_location_rounded, size: 20),
                      tooltip: l10n.setMyLocation,
                      color: cs.primary,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildShoppingListSection(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    final showSubUnits = _selectedUnit == 'kg' || _selectedUnit == 'piece';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart_outlined, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.shoppingList,
                style: AppTextStyles.titleMedium.copyWith(color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_items.isNotEmpty) ...[
            ...List.generate(_items.length, (i) {
              final item = _items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(item.name, style: AppTextStyles.bodyMedium),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _itemDisplayText(item, l10n),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: () => _removeItem(i),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: cs.error,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
            const SizedBox(height: 4),
          ],

          Column(
            children: [
              TextField(
                controller: _itemNameController,
                decoration: InputDecoration(
                  hintText: l10n.itemName,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    child: TextField(
                      controller: _itemQtyController,
                      focusNode: _qtyFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                        hintText: '1',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildUnitSelector(l10n, cs),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: l10n.addItem,
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (showSubUnits) ...[
            const SizedBox(height: 8),
            _buildSubUnitSelector(l10n, cs),
          ],
        ],
      ),
    );
  }

  Widget _buildUnitSelector(AppLocalizations l10n, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedUnit,
          isDense: true,
          style: AppTextStyles.labelSmall.copyWith(color: cs.onSurface),
          items: [
            DropdownMenuItem(value: 'none', child: Text(l10n.unitNone)),
            DropdownMenuItem(value: 'piece', child: Text(l10n.unitPiece)),
            DropdownMenuItem(value: 'kg', child: Text(l10n.unitKg)),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() {
                _selectedUnit = v;
                _selectedWeight = 'none';
                _selectedPieceUnit = 'none';
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildSubUnitSelector(AppLocalizations l10n, ColorScheme cs) {
    if (_selectedUnit == 'kg') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.scale_outlined, size: 16, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedWeight,
                  isDense: true,
                  isExpanded: true,
                  style: AppTextStyles.bodySmall.copyWith(color: cs.onSurface),
                  items: [
                    DropdownMenuItem(
                      value: 'none',
                      child: Text(l10n.weightNone),
                    ),
                    DropdownMenuItem(
                      value: 'bundle',
                      child: Text(l10n.weightBundle),
                    ),
                    DropdownMenuItem(
                      value: 'eighth',
                      child: Text(l10n.weightEighth),
                    ),
                    DropdownMenuItem(
                      value: 'quarter',
                      child: Text(l10n.weightQuarter),
                    ),
                    DropdownMenuItem(
                      value: 'third',
                      child: Text(l10n.weightThird),
                    ),
                    DropdownMenuItem(
                      value: 'half',
                      child: Text(l10n.weightHalf),
                    ),
                    DropdownMenuItem(
                      value: 'three_quarters',
                      child: Text(l10n.weightThreeQuarters),
                    ),
                    DropdownMenuItem(
                      value: 'fifth',
                      child: Text(l10n.weightFifth),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedWeight = v);
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.straighten_rounded, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPieceUnit,
                isDense: true,
                isExpanded: true,
                style: AppTextStyles.bodySmall.copyWith(color: cs.onSurface),
                items: [
                  DropdownMenuItem(value: 'none', child: Text(l10n.unitNone)),
                  DropdownMenuItem(
                    value: 'box',
                    child: Text(l10n.pieceUnitBox),
                  ),
                  DropdownMenuItem(
                    value: 'carton',
                    child: Text(l10n.pieceUnitCarton),
                  ),
                  DropdownMenuItem(
                    value: 'liter',
                    child: Text(l10n.pieceUnitLiter),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedPieceUnit = v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneSection(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.customerPhone,
                style: AppTextStyles.titleMedium.copyWith(color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                  ],
                  decoration: InputDecoration(
                    hintText: l10n.customerPhoneHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: l10n.saveNumber,
                onPressed: () {
                  if (_saveNumber) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.numberSaved),
                        backgroundColor: AppColors.successLight,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Checkbox(
                value: _saveNumber,
                onChanged: (v) => setState(() => _saveNumber = v ?? true),
              ),
              Text(
                l10n.saveNumber,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    int maxLines = 1,
    String? hint,
  }) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: color),
          labelText: label,
          hintText: hint,
          labelStyle: AppTextStyles.bodyMedium.copyWith(color: color),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _ShoppingItem {
  const _ShoppingItem({
    required this.name,
    required this.quantity,
    required this.unit,
    this.subUnit,
  });
  final String name;
  final int quantity;
  final String unit;
  final String? subUnit;
}
