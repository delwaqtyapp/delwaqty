import 'package:flutter/material.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_profile.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Categories a provider can request from "add another service". Values are
/// lowercased by the backend; the spelling the customer app matches on is
/// restored by `_provision_business_target` (migration 399).
const List<String> kRequestableProviderCategories = [
  'restaurant',
  'grocery',
  'bakery',
  'home_services',
  'electronics',
  'fashion',
  // Service accounts (backend provisioning knows these since migration 399).
  'teacher',
  'doctor',
  'nurse',
  'barber',
  'plumbing',
  'electrical',
  'carpentry',
  'painting',
  'cleaning',
  'acMaintenance',
  'pipeChange',
  'plastering',
  'carpetCleaning',
  'dishRepair',
  'pestControl',
  'applianceRepair',
];

/// Storefront editor category list: every shop type plus every service
/// category, generic for the provider role. A doctor, nurse, teacher or
/// barber storefront keeps its real type here instead of being coerced to a
/// restaurant or labelled "Other".
const List<String> kStorefrontProviderCategories = [
  'restaurant',
  'grocery',
  'bakery',
  'cafe',
  'electronics',
  'fashion',
  'home_services',
  'teacher',
  'doctor',
  'nurse',
  'barber',
  'plumbing',
  'electrical',
  'carpentry',
  'painting',
  'cleaning',
  'acMaintenance',
  'pipeChange',
  'plastering',
  'carpetCleaning',
  'dishRepair',
  'pestControl',
  'applianceRepair',
  'other',
];

bool isServiceProviderCategory(String category) {
  final family = ProviderProfile.familyOf(ProviderCategory.normalize(category));
  return family == ProviderFamily.homeServices ||
      family == ProviderFamily.professional;
}

String providerCategoryLabel(AppLocalizations l10n, String category) {
  switch (category.toLowerCase()) {
    case 'restaurant':
      return l10n.restaurant;
    case 'grocery':
      return l10n.grocery;
    case 'bakery':
      return l10n.bakery;
    case 'cafe':
      return l10n.cafe;
    case 'electronics':
      return l10n.electronics;
    case 'fashion':
      return l10n.fashion;
    case 'home_services':
      return l10n.homeServices;
    case 'teacher':
      return l10n.serviceCategoryTeacher;
    case 'doctor':
      return l10n.serviceCategoryDoctor;
    case 'nurse':
      return l10n.serviceCategoryNurse;
    case 'barber':
      return l10n.serviceCategoryBarber;
    case 'plumbing':
      return l10n.serviceCategoryPlumbing;
    case 'electrical':
      return l10n.serviceCategoryElectrical;
    case 'carpentry':
      return l10n.serviceCategoryCarpentry;
    case 'painting':
      return l10n.serviceCategoryPainting;
    case 'cleaning':
      return l10n.serviceCategoryCleaning;
    case 'acmaintenance':
    case 'ac_maintenance':
      return l10n.serviceCategoryAcMaintenance;
    case 'pipechange':
    case 'pipe_change':
      return l10n.serviceCategoryPipeChange;
    case 'plastering':
      return l10n.serviceCategoryPlastering;
    case 'carpetcleaning':
    case 'carpet_cleaning':
      return l10n.serviceCategoryCarpetCleaning;
    case 'dishrepair':
    case 'dish_repair':
      return l10n.serviceCategoryDishRepair;
    case 'pestcontrol':
    case 'pest_control':
      return l10n.serviceCategoryPestControl;
    case 'appliancerepair':
    case 'appliance_repair':
      return l10n.serviceCategoryApplianceRepair;
    default:
      return l10n.other;
  }
}

/// Category dropdown for the "request another service" dialog.
class ProviderCategoryPickerField extends StatelessWidget {
  const ProviderCategoryPickerField({
    super.key,
    required this.l10n,
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final List<String> categories;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 360,
      decoration: InputDecoration(
        labelText: l10n.storeCategoryLabel,
        border: const OutlineInputBorder(),
      ),
      items: categories
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Row(
                children: [
                  Icon(
                    isServiceProviderCategory(c)
                        ? Icons.handyman_rounded
                        : Icons.storefront_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      providerCategoryLabel(l10n, c),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
