import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bottomNavVisibleProvider = StateProvider<bool>((_) => true);

class ScrollAwareNavObserver {
  ScrollAwareNavObserver._();

  static double _lastOffset = 0;
  static double _threshold = 50;
  static bool _accumulating = false;
  static double _accumulated = 0;

  static bool handleScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) return false;
    if (notification.depth > 0) return false;

    final currentOffset = notification.metrics.pixels;
    final delta = currentOffset - _lastOffset;
    _lastOffset = currentOffset;

    if (currentOffset <= 0) {
      _reset();
      return false;
    }

    _accumulated += delta;

    if (_accumulated.abs() < _threshold) return false;

    final scrollingDown = _accumulated > 0;
    _accumulated = 0;

    return scrollingDown;
  }

  static void resetOnTop() {
    _lastOffset = 0;
    _accumulated = 0;
  }

  static void _reset() {
    _lastOffset = 0;
    _accumulated = 0;
  }
}
