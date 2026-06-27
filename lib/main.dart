import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'boot.dart';
import 'core/agent_client.dart';
import 'core/attribution_unit.dart';
import 'core/dispatch_unit.dart';
import 'core/net_sensor.dart';
import 'core/vault_unit.dart';
import 'core/wire_unit.dart';
import 'services/progress_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + AppCheck. Both are wrapped in try/catch so the app still
  // starts cleanly even when google-services.json is not yet present
  // (e.g. during the very first dry run before AppsFlyer/Firebase keys
  // are issued).
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
  } catch (_) {}

  // The whole experience is portrait by default; the bootstrap stage and
  // the portal stage themselves loosen this when they need to support
  // landscape (loading artwork and WebView respectively).
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await agentClient.warm();

  // White-flow progress (level unlocks, stars) is preserved across launches
  // so a returning arcade user lands on the same place they left.
  await ProgressService.instance.init();

  final vault = VaultUnit();
  await vault.prime();

  final netSensor = NetSensor();
  final attribution = AttributionUnit();
  final dispatcher = DispatchUnit(vault);
  final wire = WireUnit(vault);

  // Boot push as early as possible so the FCM token is available by the
  // time we assemble the dispatch body. If Firebase isn't configured this
  // returns silently and the token stays null — that is acceptable
  // (token is sent on the next launch once it becomes available).
  unawaited(wire.boot());

  runApp(DesertStrikeShell(
    vault: vault,
    netSensor: netSensor,
    attribution: attribution,
    dispatcher: dispatcher,
    wire: wire,
  ));
}

void unawaited(Future<void> _) {}
