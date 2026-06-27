import 'dart:convert';

import '../domain/dispatch_envelope.dart';
import '../env/desert_settings.dart';
import 'agent_client.dart';
import 'vault_unit.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DispatchUnit — POSTs the attribution body to the backend
// ─────────────────────────────────────────────────────────────────────────────
//  Behaviour summary:
//
//    • Endpoint is unencoded on first read (via `DesertEnv.dispatchEndpoint`).
//    • POST timeout is 15 s — the backend should answer within a couple of
//      seconds; the larger ceiling absorbs jitter on flaky mobile data.
//    • Successful envelopes that carry a portal URL are persisted to the
//      vault (URL + expiry) so the next launch can still open the portal
//      even if the dispatch endpoint is temporarily unreachable.
//    • Any non-2xx / timeout / parse error returns a failure envelope so
//      the caller can fall back to the saved URL or the white game.
// ─────────────────────────────────────────────────────────────────────────────

class DispatchUnit {
  final VaultUnit _vault;

  DispatchUnit(this._vault);

  Future<DispatchEnvelope> hit(Map<String, dynamic> body) async {
    final endpoint = DesertEnv.dispatchEndpoint;
    if (endpoint.isEmpty) {
      return DispatchEnvelope.failure('dispatch endpoint not configured');
    }

    Uri uri;
    try {
      uri = Uri.parse(endpoint);
    } catch (_) {
      return DispatchEnvelope.failure('invalid dispatch endpoint');
    }

    try {
      final response = await agentClient
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return DispatchEnvelope.failure('http ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return DispatchEnvelope.failure('malformed json');
      }

      final envelope = DispatchEnvelope.fromMap(decoded);
      if (envelope.hasPortal) {
        await _vault.writeLastPortalUrl(envelope.url!);
        if (envelope.expiresAt != null) {
          await _vault.setPortalExpiresAt(envelope.expiresAt!);
        }
      }
      return envelope;
    } catch (e) {
      return DispatchEnvelope.failure(e.toString());
    }
  }
}
