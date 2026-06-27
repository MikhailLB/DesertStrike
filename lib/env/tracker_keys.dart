import '../cipher/mask.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Tracker keys (XOR-encoded)
// ─────────────────────────────────────────────────────────────────────────────
//  Two values live here:
//
//    1. AppsFlyer Dev Key — needed to initialise the SDK. Currently a
//       placeholder; replace the byte array once the dashboard provides the
//       real key (re-encode with tool/encode_keys.dart).
//
//    2. Firebase project number — the numeric "Project number" from
//       Firebase Console → Project settings → General. Currently a
//       placeholder; replace once Firebase is created.
//
//  If either array decodes to a known placeholder, callers must treat the
//  value as "not configured yet" — the app must continue to work even
//  without these credentials (gray flow degrades to white game).
// ─────────────────────────────────────────────────────────────────────────────

// "RokekoTvCwUmenrW3CzKHS"  — AppsFlyer Dev Key (encoded via tool/encode_keys.dart)
const List<int> _trackerKey = <int>[
  0x39, 0x49, 0x39, 0xaf, 0xc8, 0xbe, 0x8a, 0x4a, 0x1c, 0xb0, 0xf3, 0x42,
  0xb6, 0xad, 0x35, 0x93, 0x58, 0x65, 0x28, 0x81, 0xeb, 0x82,
];

// "770864626410"  — Firebase project number for desertsrike-f5bf3
const List<int> _messagingProject = <int>[
  0x5c, 0x11, 0x62, 0xf2, 0x95, 0xe5, 0xe8, 0x0e, 0x69, 0xf3, 0x97, 0x1f,
];

/// Decoded AppsFlyer Dev Key. Empty string means "not configured" — callers
/// must continue to function (the gray flow simply skips attribution).
String unwrapTrackerKey() {
  final v = mask(_trackerKey);
  if (v.isEmpty || v.contains('PLACEHOLDER')) return '';
  return v;
}

/// Decoded Firebase project number. Empty string means "not configured".
String unwrapMessagingProject() {
  final v = mask(_messagingProject);
  if (v.isEmpty || RegExp(r'^0+$').hasMatch(v)) return '';
  return v;
}
