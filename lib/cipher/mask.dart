import 'dart:typed_data';

// ─────────────────────────────────────────────────────────────────────────────
//  Desert Strike — XOR string unmask (project-unique seed)
// ─────────────────────────────────────────────────────────────────────────────
//  All sensitive strings (the dispatch endpoint URL, the attribution Dev Key,
//  the messaging project number, and the browser version fragments used in the
//  User-Agent) live in this binary as XOR-encoded byte arrays. They are
//  expanded into UTF-8 strings on first read via [mask].
//
//  The XOR stream is derived from the seed phrase below using a Mulberry32
//  pseudo-random sequence. The seed phrase is the ONLY thing that makes this
//  project's encoded payloads different from another title's — it MUST be
//  changed for every new app or two different binaries will share the same
//  obfuscation pattern (a soft fingerprint).
//
//  Workflow:
//    1) Change `_seedTokens` below.
//    2) Run `dart run tool/encode_keys.dart` to regenerate every byte array.
//    3) Paste the new arrays into env/endpoint_codec.dart + env/tracker_keys.dart
//       and core/agent_client.dart.
// ─────────────────────────────────────────────────────────────────────────────

/// Seed phrase used to derive the XOR stream. UNIQUE PER PROJECT.
/// Bytes spell "chsdsrt2026" (chaos · desert · strike · 2026).
const List<int> _seedTokens = <int>[
  0x63, 0x68, 0x73, 0x64, 0x73, 0x72, 0x74, 0x32, 0x30, 0x32, 0x36,
];

/// 32-bit Java-style string hash of the seed tokens.
int _signature() {
  int sig = 0;
  for (final t in _seedTokens) {
    sig = ((sig << 5) - sig + t) & 0xFFFFFFFF;
  }
  return sig;
}

/// Expand the seed signature into a 16-byte Mulberry32 stream.
/// Reference: Tommy Ettinger's Mulberry32 PRNG (public domain).
Uint8List _spinStream() {
  final stream = Uint8List(16);
  int state = _signature();
  for (var i = 0; i < stream.length; i++) {
    state = (state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = state;
    t = ((t ^ (t >>> 15)) * (t | 1)) & 0xFFFFFFFF;
    t = (t ^ (t + ((t ^ (t >>> 7)) * (t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    stream[i] = ((t ^ (t >>> 14)) & 0xFF);
  }
  return stream;
}

final Uint8List _stream = _spinStream();

/// Restore the original UTF-8 string from an XOR-encoded payload.
///
/// Pass arrays produced by `tool/encode_keys.dart`. Returns empty string on
/// an empty input — callers should treat that as "not configured".
String mask(List<int> payload) {
  if (payload.isEmpty) return '';
  final out = Uint8List(payload.length);
  for (var i = 0; i < payload.length; i++) {
    out[i] = payload[i] ^ _stream[i % _stream.length];
  }
  return String.fromCharCodes(out);
}
