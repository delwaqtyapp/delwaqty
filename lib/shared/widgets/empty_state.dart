import 'package:delwaqty/shared/widgets/app_empty_state.dart';
import 'package:flutter/material.dart';

/// Kept for backwards compatibility. New code uses [AppEmptyState].
@Deprecated('Use AppEmptyState instead')
class EmptyState extends AppEmptyState {
  const EmptyState({
    super.key,
    required super.icon,
    required super.title,
    required super.message,
    super.actionLabel,
    super.onAction,
  });
}
