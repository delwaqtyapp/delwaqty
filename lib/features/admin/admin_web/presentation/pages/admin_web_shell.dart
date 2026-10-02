import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/admin/admin_web/presentation/pages/admin_categories_page.dart';
import 'package:delwaqty/features/admin/admin_web/presentation/pages/admin_overview_page.dart';
import 'package:delwaqty/features/admin/admin_web/presentation/pages/admin_region_scope_page.dart';
import 'package:delwaqty/features/admin_management/presentation/pages/admin_management_list_page.dart';
import 'package:delwaqty/features/admin/admin_web/presentation/pages/admin_verifications_page.dart';

class AdminWebShell extends StatefulWidget {
  const AdminWebShell({super.key});

  @override
  State<AdminWebShell> createState() => _AdminWebShellState();
}

class _AdminWebShellState extends State<AdminWebShell> {
  int _selectedIndex = 0;

  final _pages = const [
    AdminOverviewPage(),
    AdminManagementListPage(),
    AdminVerificationsWebPage(),
    AdminCategoriesPage(),
    AdminRegionScopePage(),
  ];

  final _navItems = const [
    (Icons.dashboard_rounded, 'Dashboard'),
    (Icons.people_rounded, 'Users'),
    (Icons.verified_rounded, 'Verifications'),
    (Icons.category_rounded, 'Categories'),
    (Icons.location_city_rounded, 'Region Scope'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final rail = constraints.maxWidth < 880;
          return Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: rail ? 76 : 240,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 72,
                      padding: EdgeInsets.symmetric(
                        horizontal: rail ? 0 : 20,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.brandPurple,
                                  AppColors.brandCyan,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text(
                                'D',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          if (!rail) ...[
                            const SizedBox(width: 12),
                            const Flexible(
                              child: Text(
                                'Delwaqty Admin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _navItems.length; i++)
                      _NavItem(
                        icon: _navItems[i].$1,
                        label: _navItems[i].$2,
                        showLabel: !rail,
                        selected: _selectedIndex == i,
                        onTap: () => setState(() => _selectedIndex = i),
                      ),
                    const Spacer(),
                    if (rail) const SizedBox(height: 16),
                    if (!rail)
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Divider(color: Colors.white12, height: 1),
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: rail ? 0 : 16,
                      ),
                      child: _NavItem(
                        icon: Icons.logout_rounded,
                        label: 'Sign out',
                        showLabel: !rail,
                        selected: false,
                        onTap: () => Supabase.instance.client.auth.signOut(),
                      ),
                    ),
                    if (!rail)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Delwaqty v1.0',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _pages,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.showLabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool showLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: selected ? label : label,
          waitDuration: const Duration(milliseconds: 400),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: showLabel ? double.infinity : null,
              padding: EdgeInsets.symmetric(
                horizontal: showLabel ? 16 : 0,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.brandPurple.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: selected ? AppColors.brandViolet : Colors.white54,
                    size: 20,
                  ),
                  if (showLabel) ...[
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white54,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}