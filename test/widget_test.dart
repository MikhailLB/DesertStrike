// Smoke test — verifies the cipher decodes the dispatch endpoint without
// pulling in Flutter bindings (which would also need a full mock of the
// service singletons). The dart-only check is enough to catch a seed
// drift between cipher/mask.dart and tool/encode_keys.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:desert_strike/env/desert_settings.dart';

void main() {
  test('Dispatch endpoint decodes to the expected URL', () {
    expect(
      DesertEnv.dispatchEndpoint,
      equals('https://deserttstrike.com/config.php'),
    );
  });

  test('Bundle slug matches Android applicationId', () {
    expect(DesertEnv.bundleSlug, equals('com.chaosdesert.desertstrike'));
  });
}
