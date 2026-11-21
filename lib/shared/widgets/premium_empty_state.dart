import 'package:delwaqty/shared/widgets/app_empty_state.dart';

/// Kept for backwards compatibility. New code uses [AppEmptyState].
@Deprecated('Use AppEmptyState instead')
class PremiumEmptyState extends AppEmptyState {
  const PremiumEmptyState({
    super.key,
    required super.icon,
    required super.title,
    required super.message,
    super.actionLabel,
    super.onAction,
    super.illustrationColor,
  });
}
