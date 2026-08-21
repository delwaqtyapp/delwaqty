import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:delwaqty/features/customer/search/data/cache/debouncer.dart';
import 'package:delwaqty/features/customer/search/domain/entities/geo_point.dart';
import 'package:delwaqty/features/customer/search/domain/entities/place_suggestion.dart';
import 'package:delwaqty/features/customer/search/domain/entities/search_session.dart';
import 'package:delwaqty/features/customer/search/domain/geocoding_provider.dart';
import 'package:delwaqty/features/customer/search/presentation/providers/search_providers.dart';

enum SearchStatus { idle, loading, results, empty, error }

class DestinationSearchState {
  const DestinationSearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.suggestions = const [],
    this.errorKind,
  });

  final String query;
  final SearchStatus status;
  final List<PlaceSuggestion> suggestions;
  final GeocodingErrorKind? errorKind;

  DestinationSearchState copyWith({
    String? query,
    SearchStatus? status,
    List<PlaceSuggestion>? suggestions,
    GeocodingErrorKind? errorKind,
    bool clearError = false,
  }) {
    return DestinationSearchState(
      query: query ?? this.query,
      status: status ?? this.status,
      suggestions: suggestions ?? this.suggestions,
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
    );
  }
}

class DestinationSearchController
    extends StateNotifier<DestinationSearchState> {
  DestinationSearchController(this._ref, {GeoPoint? origin})
      : _origin = origin,
        super(const DestinationSearchState());

  final Ref _ref;
  final GeoPoint? _origin;
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 350));

  SearchSession _session = SearchSession.generate();
  int _requestId = 0;

  void onQueryChanged(String value) {
    final query = value;
    state = state.copyWith(query: query, clearError: true);
    if (query.trim().length < 2) {
      _debouncer.cancel();
      state = state.copyWith(
          status: SearchStatus.idle, suggestions: const []);
      return;
    }
    state = state.copyWith(status: SearchStatus.loading);
    _debouncer.run(_search);
  }

  Future<void> _search() async {
    final query = state.query.trim();
    if (query.length < 2) return;
    final requestId = ++_requestId;
    try {
      final repo = _ref.read(placesRepositoryProvider);
      final lang = _ref.read(searchLanguageProvider);
      final results = await repo.autocomplete(
        query: query,
        languageCode: lang,
        origin: _origin,
        session: _session,
      );
      if (requestId != _requestId) return;
      state = state.copyWith(
        suggestions: results,
        status: results.isEmpty ? SearchStatus.empty : SearchStatus.results,
        clearError: true,
      );
    } on GeocodingException catch (e) {
      if (requestId != _requestId) return;
      state = state.copyWith(status: SearchStatus.error, errorKind: e.kind);
    } catch (_) {
      if (requestId != _requestId) return;
      state = state.copyWith(
          status: SearchStatus.error,
          errorKind: GeocodingErrorKind.unknown);
    }
  }

  void retry() {
    if (state.query.trim().length >= 2) {
      state = state.copyWith(status: SearchStatus.loading, clearError: true);
      _search();
    }
  }

  SearchSession get session => _session;

  /// Call after a place is selected/committed to end the billing session.
  void resetSession() {
    _session = SearchSession.generate();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }
}

final destinationSearchControllerProvider = StateNotifierProvider.autoDispose
    .family<DestinationSearchController, DestinationSearchState, GeoPoint?>(
  (ref, origin) => DestinationSearchController(ref, origin: origin),
);
