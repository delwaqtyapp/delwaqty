import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:delwaqty/services/logger/app_logger.dart';

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService(ref.watch(loggerProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Centralized Supabase Realtime channel manager.
///
/// Tracks all active channels and ensures proper cleanup on dispose.
/// All channel subscriptions should go through this service to prevent
/// leaked WebSocket connections.
class RealtimeService {
  RealtimeService(this._logger);

  final AppLogger _logger;
  final Map<String, RealtimeChannel> _channels = {};
  bool _disposed = false;

  int get activeChannelCount => _channels.length;

  /// Subscribe to a channel with automatic tracking and error handling.
  ///
  /// If a channel with [channelName] already exists, the old one is
  /// unsubscribed first.
  RealtimeChannel subscribe({
    required String channelName,
    List<RealtimeChannelFilter>? opts,
    void Function(RealtimeChannel channel)? onSubscribed,
    void Function(String errorMsg)? onError,
  }) {
    if (_disposed) {
      _logger.w('RealtimeService disposed, ignoring subscribe: $channelName');
      return _dummyChannel(channelName);
    }

    final existing = _channels.remove(channelName);
    if (existing != null) {
      try {
        existing.unsubscribe();
      } catch (_) {}
    }

    final client = Supabase.instance.client;
    final channel = client.channel(channelName);

    if (opts != null && opts.isNotEmpty) {
      channel.onPostgresChanges(
        event: opts.first.event,
        schema: opts.first.schema,
        table: opts.first.table,
        filter: opts.first.filter,
        callback: opts.first.callback,
      );
    }

    channel.subscribe((status, error) {
      if (error != null) {
        _logger.e('Realtime channel error: $channelName', error);
        onError?.call(error.toString());
      }
      if (status == RealtimeSubscribeStatus.subscribed) {
        _logger.d('Realtime subscribed: $channelName');
        onSubscribed?.call(channel);
      } else if (status == RealtimeSubscribeStatus.closed) {
        _channels.remove(channelName);
      }
    });

    _channels[channelName] = channel;
    return channel;
  }

  /// Unsubscribe from a specific channel.
  Future<void> unsubscribe(String channelName) async {
    final channel = _channels.remove(channelName);
    if (channel != null) {
      try {
        await channel.unsubscribe();
      } catch (e) {
        _logger.w('Error unsubscribing from $channelName: $e');
      }
    }
  }

  /// Unsubscribe from all tracked channels.
  Future<void> unsubscribeAll() async {
    final names = List<String>.from(_channels.keys);
    for (final name in names) {
      await unsubscribe(name);
    }
  }

  /// Dispose the service — unsubscribe all channels.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final entry in _channels.entries) {
      try {
        entry.value.unsubscribe();
      } catch (_) {}
    }
    _channels.clear();
  }
}

/// Simple filter descriptor for PostgresChanges subscriptions.
class RealtimeChannelFilter {
  const RealtimeChannelFilter({
    required this.event,
    required this.schema,
    required this.table,
    this.filter,
    required this.callback,
  });

  final PostgresChangeEvent event;
  final String schema;
  final String table;
  final PostgresChangeFilter? filter;
  final void Function(PostgresChangePayload payload) callback;
}

RealtimeChannel _dummyChannel(String name) {
  return Supabase.instance.client.channel(name);
}
