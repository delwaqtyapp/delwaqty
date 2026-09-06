import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/legacy.dart';

final bottomNavVisibleProvider = StateProvider<bool>((_) => true);

class ScrollAwareNavObserver {
  ScrollAwareNavObserver._();

  static double _lastOffset = 0;
  static bool _isVisible = true;
  static double _accumulated = 0;

  static const double _showThreshold = 40;
  static const double _hideThreshold = 50;

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

    if (_isVisible && _accumulated > _hideThreshold) {
      _isVisible = false;
      _accumulated = 0;
      return true;
    }

    if (!_isVisible && _accumulated < -_showThreshold) {
      _isVisible = true;
      _accumulated = 0;
      return false;
    }

    if (_accumulated.abs() > _hideThreshold) {
      _accumulated = 0;
    }

    return !_isVisible;
  }

  static void resetOnTop() {
    _lastOffset = 0;
    _accumulated = 0;
    _isVisible = true;
  }

  static void _reset() {
    _lastOffset = 0;
    _accumulated = 0;
    _isVisible = true;
  }
}
