/// Accept the response shapes used by the platform's SQL RPCs.
/// A transport-level 200 can still contain a rejected operation.
Map<String, dynamic> checkedRpcResult(
  dynamic data, {
  required Exception Function(String reason) onFailure,
}) {
  final map = Map<String, dynamic>.from(data as Map);
  if (map['success'] == false || map['ok'] == false || map['error'] != null) {
    final reason = map['reason'] ?? map['code'] ?? map['error'] ?? 'unknown';
    throw onFailure(reason.toString());
  }
  return map;
}
