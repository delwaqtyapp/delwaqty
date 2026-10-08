import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/core/module/feature_registry.dart';

/// Aggregates the per-module unread badge counts into one stream.
///
/// The previous version created a broadcast controller and subscribed to
/// every module stream but never disposed either of them, and it had no
/// `ref.onDispose`. Each module's polling timer therefore leaked for the
/// lifetime of the process and the controller kept a live subscription
/// after the last listener went away.
final badgeAggregatorProvider = StreamProvider<Map<String, int>>((ref) {
  final registry = FeatureRegistry.instance;
  final controller = StreamController<Map<String, int>>.broadcast();
  final subscriptions = <StreamSubscription<int>>[];
  final currentCounts = <String, int>{};

  ref.onDispose(() {
    for (final sub in subscriptions) {
      sub.cancel();
    }
    controller.close();
  });

  for (final m in registry.modules) {
    if (!m.capabilities.contains(ModuleCapability.hasNotifications)) continue;
    final moduleStream = m.badgeStream(ref);
    if (moduleStream != null) {
      subscriptions.add(
        moduleStream.listen((count) {
          currentCounts[m.id] = count;
          controller.add(Map.from(currentCounts));
        }),
      );
    }
  }

  if (currentCounts.isEmpty) {
    // Nothing to aggregate: close immediately instead of handing back a
    // controller that would stay open forever.
    unawaited(controller.close());
    return Stream.value(const {});
  }

  controller.add(Map.from(currentCounts));
  return controller.stream;
});

final totalUnreadProvider = Provider<int>((ref) {
  final counts = ref.watch(badgeAggregatorProvider).value ?? const {};
  return counts.values.fold(0, (sum, c) => sum + c);
});