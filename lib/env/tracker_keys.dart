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

// "AF_DEV_KEY_PLACEHOLDER"  ← replace after re-encoding
const List<int> _trackerKey = <int>[
  0x2a, 0x60, 0x0d, 0x8e, 0xe6, 0x87, 0x81, 0x77, 0x1a, 0x9e, 0xf9, 0x7f,
  0x9f, 0x82, 0x04, 0x81, 0x23, 0x69, 0x1e, 0x8e, 0xe6, 0x83,
];

// "000000000000"  ← replace after re-encoding
const List<int> _messagingProject = <int>[
  0x5b, 0x16, 0x62, 0xfa, 0x93, 0xe1, 0xee, 0x0c, 0x6f, 0xf7, 0x96, 0x1f,
];

/// Decoded AppsFlyer Dev Key, or empty string if still a placeholder.
String unwrapTrackerKey() {
  final v = mask(_trackerKey);
  if (v.isEmpty || v.contains('PLACEHOLDER')) return '';
  return v;
}

/// Decoded Firebase project number, or empty string if still a placeholder.
String unwrapMessagingProject() {
  final v = mask(_messagingProject);
  if (v.isEmpty || RegExp(r'^0+$').hasMatch(v)) return '';
  return v;
}
