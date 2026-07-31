import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'sidebar_theme.dart';

class SidebarHeader extends StatelessWidget {
  const SidebarHeader({
    super.key,
    required this.userName,
    this.userEmail,
    this.avatarInitial,
    this.roleBadge,
    this.onEditProfile,
    this.walletBalance,
    this.membershipLevel,
  });

  final String userName;
  final String? userEmail;
  final String? avatarInitial;
  final String? roleBadge;
  final VoidCallback? onEditProfile;
  final String? walletBalance;
  final String? membershipLevel;

  @override
  Widget build(BuildContext context) {
    final st = Theme.of(context).extension<SidebarTheme>()!;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.tertiary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        avatarInitial ?? (userName.isNotEmpty ? userName[0].toUpperCase() : 'U'),
                        style: AppTextStyles.titleLarge.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF34D399),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: st.cardGradientTop,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: st.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (userEmail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        userEmail!,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: st.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (onEditProfile != null)
                GestureDetector(
                  onTap: onEditProfile,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: st.quickSettingsBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: st.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          if (roleBadge != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withValues(alpha: 0.15),
                    cs.tertiary.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 12,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    roleBadge!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (walletBalance != null || membershipLevel != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (walletBalance != null)
                  _InfoChip(
                    icon: Icons.account_balance_wallet_rounded,
                    label: walletBalance!,
                    st: st,
                  ),
                if (walletBalance != null && membershipLevel != null)
                  const SizedBox(width: 8),
                if (membershipLevel != null)
                  _InfoChip(
                    icon: Icons.diamond_rounded,
                    label: membershipLevel!,
                    st: st,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.st,
  });

  final IconData icon;
  final String label;
  final SidebarTheme st;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: st.quickSettingsBackground,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: st.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: st.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
