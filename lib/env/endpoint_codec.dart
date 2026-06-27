import '../cipher/mask.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Dispatch endpoint payloads (XOR-encoded)
// ─────────────────────────────────────────────────────────────────────────────
//  These byte arrays were produced by `dart run tool/encode_keys.dart` with
//  the seed phrase declared in lib/cipher/mask.dart. Regenerate them whenever
//  the seed phrase changes — otherwise the decoded strings will be garbage.
// ─────────────────────────────────────────────────────────────────────────────

// "https://deserttstrike.com/config.php"
const List<int> _dispatchUrl = <int>[
  0x03, 0x52, 0x26, 0xba, 0xd0, 0xeb, 0xf1, 0x13, 0x3b, 0xa2, 0xd5, 0x4a,
  0xa1, 0xb7, 0x33, 0xb7, 0x1f, 0x54, 0x3b, 0xa1, 0xc6, 0xff, 0xbd, 0x53,
  0x32, 0xe8, 0xc5, 0x40, 0xbd, 0xa5, 0x2e, 0xa3, 0x45, 0x56, 0x3a, 0xba,
];

// "https://gcdsdk.appsflyer.com"
const List<int> _gcdHost = <int>[
  0x03, 0x52, 0x26, 0xba, 0xd0, 0xeb, 0xf1, 0x13, 0x38, 0xa4, 0xc2, 0x5c,
  0xb7, 0xa8, 0x69, 0xa5, 0x1b, 0x56, 0x21, 0xac, 0xcf, 0xa8, 0xbb, 0x4e,
  0x71, 0xa4, 0xc9, 0x42,
];

// "/install_data/v4.0/"
const List<int> _gcdPath = <int>[
  0x44, 0x4f, 0x3c, 0xb9, 0xd7, 0xb0, 0xb2, 0x50, 0x00, 0xa3, 0xc7, 0x5b,
  0xb2, 0xec, 0x31, 0xf0, 0x45, 0x16, 0x7d,
];

/// The full dispatch endpoint URL the app POSTs the attribution body to.
String unwrapDispatchEndpoint() => mask(_dispatchUrl);

/// Builds the AppsFlyer GCD URL used to retry attribution when the SDK
/// reports a (potentially false) "Organic" status on first launch.
///
/// Format produced:
///   https://gcdsdk.appsflyer.com/install_data/v4.0/{bundleId}?app_id=...&device_id=...
String unwrapGcdEndpoint({
  required String bundleId,
  required String deviceId,
  required String appId,
}) {
  final host = mask(_gcdHost);
  final path = mask(_gcdPath);
  if (host.isEmpty || path.isEmpty) return '';
  return '$host$path$bundleId?app_id=$appId&device_id=$deviceId';
}
