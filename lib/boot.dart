import 'package:flutter/material.dart';

import 'core/attribution_unit.dart';
import 'core/dispatch_unit.dart';
import 'core/net_sensor.dart';
import 'core/vault_unit.dart';
import 'core/wire_unit.dart';
import 'flow/bootstrap_stage.dart';

/// Root widget. Holds the long-lived service singletons (vault, sensors,
/// attribution, dispatch, wire) so the rest of the tree can pull them via
/// constructor injection.
class DesertStrikeShell extends StatelessWidget {
  final VaultUnit vault;
  final NetSensor netSensor;
  final AttributionUnit attribution;
  final DispatchUnit dispatcher;
  final WireUnit wire;

  const DesertStrikeShell({
    super.key,
    required this.vault,
    required this.netSensor,
    required this.attribution,
    required this.dispatcher,
    required this.wire,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DesertStrike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF14080A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE08A2B),
          brightness: Brightness.dark,
        ),
      ),
      home: BootstrapStage(
        vault: vault,
        netSensor: netSensor,
        attribution: attribution,
        dispatcher: dispatcher,
        wire: wire,
      ),
    );
  }
}
