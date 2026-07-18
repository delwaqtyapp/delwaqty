class _Entry<V> {
  _Entry(this.value, this.expiresAt);
  final V value;
  final DateTime expiresAt;
}

/// Small in-memory LRU cache with per-entry TTL.
class TtlCache<K, V> {
  TtlCache({this.maxEntries = 100, this.ttl = const Duration(minutes: 5)});

  final int maxEntries;
  final Duration ttl;
  final Map<K, _Entry<V>> _store = {};

  V? get(K key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _store.remove(key);
      return null;
    }
    _store.remove(key);
    _store[key] = entry;
    return entry.value;
  }

  void put(K key, V value) {
    _store.remove(key);
    _store[key] = _Entry(value, DateTime.now().add(ttl));
    if (_store.length > maxEntries) {
      _store.remove(_store.keys.first);
    }
  }

  void clear() => _store.clear();

  int get length => _store.length;
}
