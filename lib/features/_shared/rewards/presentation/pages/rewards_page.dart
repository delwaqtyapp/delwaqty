import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/_shared/rewards/presentation/rewards_providers.dart';
import 'package:delwaqty/features/_shared/rewards/domain/entities/member_reward.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class RewardsPage extends ConsumerWidget {
  const RewardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rewardsAsync = ref.watch(myRewardsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rewards)),
      body: rewardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(l10n.error),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(myRewardsProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (rewards) {
          if (rewards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.card_giftcard_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noRewards,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      l10n.noRewardsMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rewards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final reward = rewards[index];
              return _RewardCard(reward: reward, l10n: l10n);
            },
          );
        },
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward, required this.l10n});

  final MemberReward reward;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isBirthday = reward.rewardType == RewardType.birthday;
    final color = isBirthday ? AppColors.brandPurple : AppColors.successLight;
    final icon = isBirthday
        ? Icons.cake_outlined
        : Icons.auto_awesome_outlined;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBirthday ? l10n.rewardBirthday : l10n.rewardAnniversary,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _periodLabel(reward, l10n),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatusChip(status: reward.status, l10n: l10n),
                      const SizedBox(width: 8),
                      Text(
                        _benefitLabel(reward.benefitKind, l10n),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (reward.benefitCode != null) ...[
                    const SizedBox(height: 8),
                    _BenefitCode(code: reward.benefitCode!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(MemberReward reward, AppLocalizations l10n) {
    if (reward.rewardType == RewardType.birthday) {
      final year = reward.birthdayYear;
      if (year != null) return l10n.rewardPeriodBirthday(year);
      return l10n.rewardBirthday;
    }
    final years = reward.anniversaryYears;
    if (years != null) return l10n.rewardPeriodAnniversary(years);
    return l10n.rewardAnniversary;
  }

  String _benefitLabel(String kind, AppLocalizations l10n) {
    switch (kind) {
      case 'coupon':
        return l10n.benefitCoupon;
      case 'promo_code':
        return l10n.benefitPromoCode;
      case 'offer':
        return l10n.benefitOffer;
      case 'code_copy':
        return l10n.benefitCodeCopy;
      case 'free_delivery':
        return l10n.benefitFreeDelivery;
      default:
        return l10n.benefitNone;
    }
  }
}

class _BenefitCode extends StatelessWidget {
  const _BenefitCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.confirmation_number_outlined,
              size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              code,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.l10n});

  final RewardStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    String label;
    Color color;

    switch (status) {
      case RewardStatus.granted:
        label = l10n.rewardStatusGranted;
        color = colorScheme.primary;
      case RewardStatus.claimed:
        label = l10n.rewardStatusClaimed;
        color = AppColors.successLight;
      case RewardStatus.expired:
        label = l10n.rewardStatusExpired;
        color = AppColors.errorLight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
