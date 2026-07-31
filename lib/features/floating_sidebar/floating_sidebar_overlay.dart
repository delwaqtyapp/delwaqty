import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'sidebar_theme.dart';
import 'animations.dart';
import 'sidebar_header.dart';
import 'sidebar_section.dart';
import 'sidebar_item.dart';
import 'quick_settings_card.dart';
import 'footer_card.dart';

class FloatingSidebarOverlay extends StatefulWidget {
  const FloatingSidebarOverlay({
    super.key,
    required this.authState,
    required this.l10n,
    required this.themeMode,
    required this.locale,
    required this.ref,
    required this.onDismiss,
  });

  final AuthState authState;
  final AppLocalizations l10n;
  final ThemeMode themeMode;
  final Locale locale;
  final WidgetRef ref;
  final VoidCallback onDismiss;

  @override
  State<FloatingSidebarOverlay> createState() => _FloatingSidebarOverlayState();
}

class _FloatingSidebarOverlayState extends State<FloatingSidebarOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigate(String path) {
    widget.onDismiss();
    context.push(path);
  }

  void _navigateReplace(String path) {
    widget.onDismiss();
    context.go(path);
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.l10n.logout),
        content: Text(widget.l10n.areYouSureYouWantToLogout),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(widget.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onDismiss();
              widget.ref.read(authStateProvider.notifier).signOut();
            },
            child: Text(
              widget.l10n.logout,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = Theme.of(context).extension<SidebarTheme>()!;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final sidebarWidth = screenWidth > 380 ? 330.0 : screenWidth - 40;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    final userName = widget.authState is AuthAuthenticated
        ? (widget.authState as AuthAuthenticated).user.fullName ?? widget.l10n.user
        : widget.l10n.user;
    final isAdmin = widget.authState is AuthAuthenticated &&
            (widget.authState as AuthAuthenticated).user.role == 'admin' ||
        (widget.authState is AuthAuthenticated &&
            (widget.authState as AuthAuthenticated).user.role == 'owner');
    final displayRole = isAdmin ? widget.l10n.superAdmin : null;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.translucent,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          Positioned(
            top: 70,
            right: isRtl ? 16 : null,
            left: isRtl ? null : 16,
            child: ScaleFadeAnimation(
              controller: _animation,
              beginScale: 0.92,
              child: SlideDownAnimation(
                controller: _animation,
                beginOffset: Offset(isRtl ? 20 : -20, -10),
                child: SizedBox(
                  width: sidebarWidth.clamp(290, 340),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [st.cardGradientTop, st.cardGradientBottom],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: st.cardBorderColor,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: st.cardShadowColor,
                              blurRadius: 50,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(
                          maxHeight: screenHeight * 0.82,
                        ),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SidebarHeader(
                                userName: userName,
                                userEmail: widget.authState is AuthAuthenticated
                                    ? (widget.authState as AuthAuthenticated).user.email
                                    : null,
                                roleBadge: displayRole,
                                onEditProfile: () => _navigate('/profile'),
                              ),
                              SidebarDivider(),
                              SidebarSection(
                                title: widget.l10n.mainSection,
                                controller: _animation,
                                startIndex: 0,
                                items: [
                                  SidebarItem(
                                    icon: Icons.home_rounded,
                                    label: widget.l10n.appTitle,
                                    isSelected: _selectedIndex == 0,
                                    onTap: () {
                                      setState(() => _selectedIndex = 0);
                                      _navigateReplace('/home');
                                    },
                                  ),
                                  SidebarItem(
                                    icon: Icons.person_outline_rounded,
                                    label: widget.l10n.profile,
                                    isSelected: _selectedIndex == 1,
                                    onTap: () {
                                      setState(() => _selectedIndex = 1);
                                      _navigate('/profile');
                                    },
                                  ),
                                  SidebarItem(
                                    icon: Icons.shopping_bag_outlined,
                                    label: widget.l10n.orders,
                                    isSelected: _selectedIndex == 2,
                                    onTap: () {
                                      setState(() => _selectedIndex = 2);
                                      _navigate('/market/orders');
                                    },
                                  ),
                                  SidebarItem(
                                    icon: Icons.favorite_outline_rounded,
                                    label: widget.l10n.favorites,
                                    isSelected: _selectedIndex == 3,
                                    onTap: () {
                                      setState(() => _selectedIndex = 3);
                                      _navigate('/market/favorites');
                                    },
                                  ),
                                ],
                              ),
                              SidebarDivider(),
                              SidebarSection(
                                title: widget.l10n.servicesSection,
                                controller: _animation,
                                startIndex: 5,
                                items: [
                                  SidebarItem(
                                    icon: Icons.notifications_outlined,
                                    label: widget.l10n.notifications,
                                    isSelected: _selectedIndex == 4,
                                    onTap: () {
                                      setState(() => _selectedIndex = 4);
                                      _navigate('/notifications');
                                    },
                                  ),
                                  SidebarItem(
                                    icon: Icons.shield_outlined,
                                    label: widget.l10n.securityCenter,
                                    isSelected: _selectedIndex == 5,
                                    onTap: () {
                                      setState(() => _selectedIndex = 5);
                                      _navigate('/settings/privacy-security');
                                    },
                                  ),
                                  SidebarItem(
                                    icon: Icons.mic_rounded,
                                    label: widget.l10n.serviceAudioLogs,
                                    isSelected: _selectedIndex == 6,
                                    onTap: () {
                                      setState(() => _selectedIndex = 6);
                                      _navigate('/service-audio-logs');
                                    },
                                  ),
                                  SidebarItemWithBadge(
                                    icon: Icons.wallet_outlined,
                                    label: widget.l10n.wallet,
                                    isSelected: _selectedIndex == 7,
                                    onTap: () {
                                      setState(() => _selectedIndex = 7);
                                      _navigate('/wallet');
                                    },
                                    badgeCount: 0,
                                  ),
                                ],
                              ),
                              if (isAdmin) ...[
                                SidebarDivider(),
                                SidebarSection(
                                  title: widget.l10n.adminPanel,
                                  controller: _animation,
                                  startIndex: 8,
                                  items: [
                                    SidebarItem(
                                      icon: Icons.admin_panel_settings_outlined,
                                      label: widget.l10n.adminPanel,
                                      isSelected: _selectedIndex == 8,
                                      onTap: () {
                                        setState(() => _selectedIndex = 8);
                                        _navigate('/admin');
                                      },
                                    ),
                                    SidebarItem(
                                      icon: Icons.warning_amber_rounded,
                                      label: widget.l10n.complaints,
                                      isSelected: _selectedIndex == 9,
                                      onTap: () {
                                        setState(() => _selectedIndex = 9);
                                        _navigate('/admin/complaints');
                                      },
                                    ),
                                    SidebarItem(
                                      icon: Icons.gavel_rounded,
                                      label: widget.l10n.sanctions,
                                      isSelected: _selectedIndex == 10,
                                      onTap: () {
                                        setState(() => _selectedIndex = 10);
                                        _navigate('/admin/sanctions');
                                      },
                                    ),
                                    SidebarItem(
                                      icon: Icons.map_rounded,
                                      label: widget.l10n.liveTracking,
                                      isSelected: _selectedIndex == 11,
                                      onTap: () {
                                        setState(() => _selectedIndex = 11);
                                        _navigate('/admin/live-tracking');
                                      },
                                    ),
                                    SidebarItem(
                                      icon: Icons.chat_bubble_rounded,
                                      label: widget.l10n.supportChat,
                                      isSelected: _selectedIndex == 12,
                                      onTap: () {
                                        setState(() => _selectedIndex = 12);
                                        _navigate('/admin/support-chat');
                                      },
                                    ),
                                  ],
                                ),
                              ],
                              SidebarDivider(),
                              SidebarSection(
                                title: widget.l10n.supportSection,
                                controller: _animation,
                                startIndex: 13,
                                items: [
                                  SidebarItem(
                                    icon: Icons.feedback_outlined,
                                    label: widget.l10n.myComplaints,
                                    isSelected: _selectedIndex == 13,
                                    onTap: () {
                                      setState(() => _selectedIndex = 13);
                                      _navigate('/my-complaints');
                                    },
                                  ),
                                  SidebarItem(
                                    icon: Icons.support_agent_rounded,
                                    label: widget.l10n.support,
                                    isSelected: _selectedIndex == 14,
                                    onTap: () {
                                      setState(() => _selectedIndex = 14);
                                      _navigate('/support');
                                    },
                                  ),
                                  SidebarItem(
                                    icon: Icons.help_outline_rounded,
                                    label: widget.l10n.helpCenter,
                                    isSelected: _selectedIndex == 15,
                                    onTap: () {
                                      setState(() => _selectedIndex = 15);
                                      _navigate('/settings/help-center');
                                    },
                                  ),
                                  SidebarItem(
                                    icon: Icons.info_outline_rounded,
                                    label: widget.l10n.about,
                                    isSelected: _selectedIndex == 16,
                                    onTap: () {
                                      setState(() => _selectedIndex = 16);
                                      _navigate('/settings/about');
                                    },
                                  ),
                                  SidebarItem(
                                    icon: Icons.privacy_tip_outlined,
                                    label: widget.l10n.privacyPolicy,
                                    isSelected: _selectedIndex == 17,
                                    onTap: () {
                                      setState(() => _selectedIndex = 17);
                                      _navigate('/settings/privacy-policy');
                                    },
                                  ),
                                  SidebarItem(
                                    icon: Icons.description_outlined,
                                    label: widget.l10n.termsOfService,
                                    isSelected: _selectedIndex == 18,
                                    onTap: () {
                                      setState(() => _selectedIndex = 18);
                                      _navigate('/settings/terms-of-service');
                                    },
                                  ),
                                ],
                              ),
                              SidebarDivider(),
                              QuickSettingsCard(
                                ref: widget.ref,
                                l10n: widget.l10n,
                              ),
                              FooterCard(
                                children: [
                                  AppVersionTile(version: 'v1.0.0'),
                                  FooterTile(
                                    icon: Icons.logout_rounded,
                                    label: widget.l10n.logout,
                                    isDestructive: true,
                                    showTopBorder: true,
                                    onTap: _showLogoutDialog,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
