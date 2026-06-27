/// The decoded JSON response returned by the dispatch endpoint.
///
/// Contract:
///   {
///     "ok": true,
///     "url": "https://content.example.com/...",
///     "expires": 1689002181,
///     "message": "..."     // optional, present on failures
///   }
///
/// When `ok` is `false` (or `url` is absent) the app must show the white
/// game — the backend has decided this user does not belong to the portal
/// audience.
class DispatchEnvelope {
  final bool ok;
  final String? url;
  final int? expiresAt;
  final String? message;

  const DispatchEnvelope({
    required this.ok,
    this.url,
    this.expiresAt,
    this.message,
  });

  /// True if the envelope carries a valid portal URL.
  bool get hasPortal => ok && (url?.isNotEmpty ?? false);

  factory DispatchEnvelope.fromMap(Map<String, dynamic> map) {
    return DispatchEnvelope(
      ok: (map['ok'] as bool?) ?? false,
      url: map['url'] as String?,
      expiresAt: map['expires'] as int?,
      message: map['message'] as String?,
    );
  }

  /// Helper for the call sites that need to signal a network/transport
  /// failure without parsing JSON.
  factory DispatchEnvelope.failure(String reason) =>
      DispatchEnvelope(ok: false, message: reason);
}
