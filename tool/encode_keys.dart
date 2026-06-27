// ignore_for_file: avoid_print
//
// Standalone encoder for project secrets.
//
// Run from project root:
//   dart run tool/encode_keys.dart
//
// Copy the printed `const _xxx = <int>[...]` blocks into:
//   lib/env/endpoint_codec.dart         (dispatch endpoint URL + GCD pieces)
//   lib/env/tracker_keys.dart           (AppsFlyer Dev Key, Firebase project #)
//   lib/core/agent_client.dart          (Chrome / WebKit version fragments)
//
// This file MUST use the exact same seed/stream derivation as
// lib/cipher/mask.dart — if you change one, change both.
//
// NEVER use a PowerShell `foreach` to do this on Windows: 32-bit integer
// overflow corrupts the byte values and you get
// `FormatException: Invalid HTTP header field value` at runtime.

import 'dart:convert';
import 'dart:typed_data';

// MUST match lib/cipher/mask.dart::_seedTokens
const List<int> _seedTokens = <int>[
  0x63, 0x68, 0x73, 0x64, 0x73, 0x72, 0x74, 0x32, 0x30, 0x32, 0x36,
];

int _signature() {
  int sig = 0;
  for (final t in _seedTokens) {
    sig = ((sig << 5) - sig + t) & 0xFFFFFFFF;
  }
  return sig;
}

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

List<int> _weave(String s) {
  final raw = utf8.encode(s);
  return List<int>.generate(
    raw.length,
    (i) => raw[i] ^ _stream[i % _stream.length],
  );
}

void _emit(String label, String comment, String value) {
  final bytes = _weave(value);
  print('// $comment');
  print('//   plain: "$value"');
  print('const _$label = <int>[');
  final out = StringBuffer();
  for (var i = 0; i < bytes.length; i++) {
    if (i % 12 == 0) {
      if (out.isNotEmpty) {
        print('  ${out.toString()}');
        out.clear();
      }
    }
    out.write('0x${bytes[i].toRadixString(16).padLeft(2, '0')}, ');
  }
  if (out.isNotEmpty) print('  ${out.toString()}');
  print('];');
  print('');
}

void main() {
  print('// ─── DesertStrike encoded payloads ───');
  print('');
  _emit('endpointUrl',
      'Dispatch endpoint (POST config.php)',
      'https://deserttstrike.com/config.php');
  _emit('gcdHost',
      'AppsFlyer GCD host',
      'https://gcdsdk.appsflyer.com');
  _emit('gcdPath',
      'AppsFlyer GCD path',
      '/install_data/v4.0/');
  _emit('chromeVer',
      'Chrome version fragment for the User-Agent',
      '132.0.6834.163');
  _emit('webkitVer',
      'WebKit version fragment for the User-Agent',
      '537.36');
  _emit('trackerKey',
      'AppsFlyer Dev Key',
      'RokekoTvCwUmenrW3CzKHS');
  _emit('messagingProject',
      'Firebase project number (desertsrike-f5bf3)',
      '770864626410');
}
