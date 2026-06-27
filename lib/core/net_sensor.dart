import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NetSensor — connectivity probe with VPN/Ethernet awareness
// ─────────────────────────────────────────────────────────────────────────────
//  Two important pitfalls inform the design (gray_part_pitfalls.md §3):
//
//    * `connectivity_plus` briefly emits `[none]` while a VPN tunnel is
//      coming up. We treat that as a transient event — call sites debounce
//      their reaction by ~700ms.
//
//    * VPN, Ethernet, Bluetooth tethering and "other" must count as
//      real connectivity. Only `[none]` everywhere means we're truly off.
//
//    * The DNS probe timeout is 7 s, not 3 s — DNS through a VPN can be
//      slow but legitimate, and a true "no route" condition throws
//      SocketException instantly so the larger timeout is essentially free.
// ─────────────────────────────────────────────────────────────────────────────

const Set<ConnectivityResult> _liveLanes = <ConnectivityResult>{
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn,
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

class NetSensor {
  final Connectivity _plugin = Connectivity();

  /// Returns true if there's a usable interface AND a DNS lookup completes
  /// within 7s. Either of the two failing means we're effectively offline.
  Future<bool> reachable() async {
    final lanes = await _plugin.checkConnectivity();
    final hasLane = lanes.any(_liveLanes.contains);
    if (!hasLane) return false;

    try {
      final answer = await InternetAddress.lookup('cloudflare.com')
          .timeout(const Duration(seconds: 7));
      return answer.isNotEmpty && answer.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Stream of interface state changes — call sites debounce before
  /// reacting (otherwise a VPN handoff produces a false "offline" event).
  Stream<List<ConnectivityResult>> get laneStream =>
      _plugin.onConnectivityChanged;
}
