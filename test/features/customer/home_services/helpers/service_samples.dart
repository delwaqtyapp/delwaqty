import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';

/// Realistic category set matching production labels (Arabic + English).
final List<ServiceCategory> serviceSamples = [
  _cat('c01', ServiceCategoryType.doctor, 'طبيب', 'Doctor'),
  _cat('c02', ServiceCategoryType.nurse, 'ممرض', 'Nurse'),
  _cat('c03', ServiceCategoryType.teacher, 'معلم', 'Teacher'),
  _cat('c04', ServiceCategoryType.barber, 'حلاق', 'Barber'),
  _cat('c05', ServiceCategoryType.plumbing, 'سباك', 'Plumbing'),
  _cat('c06', ServiceCategoryType.electrical, 'كهربائي', 'Electrical'),
  _cat('c07', ServiceCategoryType.carpentry, 'نجار', 'Carpentry'),
  _cat('c08', ServiceCategoryType.painting, 'نقاش', 'Painting'),
  _cat('c09', ServiceCategoryType.cleaning, 'نظافة منازل', 'Home Cleaning'),
  _cat('c10', ServiceCategoryType.acMaintenance, 'صيانة تكييف', 'AC Maintenance'),
  _cat('c11', ServiceCategoryType.pipeChange, 'تغيير مواسير', 'Pipe Change'),
  _cat('c12', ServiceCategoryType.plastering, 'محارة', 'Plastering'),
  _cat('c13', ServiceCategoryType.carpetCleaning, 'تنجيد سجاد', 'Carpet Cleaning'),
  _cat('c14', ServiceCategoryType.dishRepair, 'تظبيط موتور', 'Dish Repair'),
  _cat('c15', ServiceCategoryType.pestControl, 'مكافحة حشرات', 'Pest Control'),
  _cat('c16', ServiceCategoryType.applianceRepair, 'صيانة أجهزة', 'Appliance Repair'),
  _cat('c17', ServiceCategoryType.other, 'خدمات أخرى', 'Other Services'),
];

ServiceCategory _cat(
  String id,
  ServiceCategoryType type,
  String ar,
  String en,
) {
  return ServiceCategory(
    id: id,
    type: type,
    nameAr: ar,
    nameEn: en,
    createdAt: DateTime(2024),
  );
}