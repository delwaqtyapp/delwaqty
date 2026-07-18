class SearchSession {
  const SearchSession(this.token);

  final String token;

  static int _counter = 0;

  static SearchSession generate() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final seq = _counter++;
    final rand = (now ^ (now >> 17) ^ (seq * 0x9E3779B1) ^ 0x5DEECE66D) &
        0x7FFFFFFFFFFFFFFF;
    return SearchSession(
        'sess_${now.toRadixString(16)}_${seq.toRadixString(16)}_${rand.toRadixString(16)}');
  }

  @override
  bool operator ==(Object other) =>
      other is SearchSession && other.token == token;

  @override
  int get hashCode => token.hashCode;
}
