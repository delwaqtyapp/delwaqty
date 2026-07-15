import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/core/module/feature_registry.dart';

final badgeAggregatorProvider = StreamProvider<Map<String, int>>((ref) {
  final registry = FeatureRegistry.instance;
  final controller = StreamController<Map<String, int>>.broadcast();
  final currentCounts = <String, int>{};

  for (final m in registry.modules) {
    if (!m.capabilities.contains(ModuleCapability.hasNotifications)) continue;
    final moduleStream = m.badgeStream(ref);
    if (moduleStream != null) {
      moduleStream.listen((count) {
        currentCounts[m.id] = count;
        controller.add(Map.from(currentCounts));
      });
    }
  }

  if (currentCounts.isEmpty) {
    return Stream.value({});
  }

  controller.add(Map.from(currentCounts));
  return controller.stream;
});

final totalUnreadProvider = Provider<int>((ref) {
  final counts =
      ref.watch(badgeAggregatorProvider).valueOrNull ?? {};
  return counts.values.fold(0, (sum, c) => sum + c);
});
