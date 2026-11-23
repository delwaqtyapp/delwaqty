/// Offset-paging state machine for the admin provider-pricing list.
///
/// Fixed page size, increasing offsets, pages appended so every row is
/// reachable. Race safety (#102): every load is stamped with a sequence
/// number; [reload] bumps it and resets both flags, so a stale [loadMore]
/// resolution returns WITHOUT touching flags (a newer [reload] already
/// owns them), and Load More can never stick disabled.
class ProviderPricingPager {
  ProviderPricingPager({required this.fetchPage, this.onChanged});

  /// Fetches one page (fixed server-side size) at [offset].
  final Future<Map<String, dynamic>> Function(int offset) fetchPage;
  final void Function()? onChanged;

  List<Map<String, dynamic>> items = [];
  int total = 0;
  bool loading = false;
  bool loadingMore = false;
  Object? error;

  /// Set only when a load-more attempt actually failed (not when it was
  /// superseded by a reload); the page surfaces this as a snackbar.
  bool loadMoreFailed = false;

  int _seq = 0;

  void _notify() => onChanged?.call();

  List<Map<String, dynamic>> _decode(Map<String, dynamic> data) =>
      (data['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<void> reload() async {
    final seq = ++_seq;
    loading = true;
    loadingMore = false; // reset: any in-flight load-more is now stale
    error = null;
    _notify();
    try {
      final data = await fetchPage(0);
      if (seq != _seq) return; // superseded by a newer reload
      items = _decode(data);
      total = (data['total'] as num?)?.toInt() ?? items.length;
      loading = false;
      _notify();
    } catch (e) {
      if (seq != _seq) return;
      error = e;
      loading = false;
      _notify();
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || items.length >= total) return;
    final seq = _seq;
    loadingMore = true;
    loadMoreFailed = false;
    _notify();
    try {
      final data = await fetchPage(items.length);
      if (seq != _seq) return; // stale: the newer reload owns the flags
      items = [...items, ..._decode(data)];
      total = (data['total'] as num?)?.toInt() ?? total;
      loadingMore = false;
      _notify();
    } catch (_) {
      if (seq != _seq) return; // stale: do not clear a newer request's flag
      loadingMore = false;
      loadMoreFailed = true;
      _notify();
    }
  }
}
