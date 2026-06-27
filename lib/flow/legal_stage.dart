import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/agent_client.dart';

/// Lightweight WebView panel used for the Privacy Policy and Support pages
/// linked from the white-flow menu. Carries the same User-Agent the rest of
/// the app uses so partner-side fingerprints remain consistent.
class LegalStage extends StatefulWidget {
  final String title;
  final String url;

  const LegalStage({super.key, required this.title, required this.url});

  @override
  State<LegalStage> createState() => _LegalStageState();
}

class _LegalStageState extends State<LegalStage> {
  late final WebViewController _ctrl;
  bool _busy = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(agentClient.userAgent)
      ..setBackgroundColor(const Color(0xFF1A1109))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _busy = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _busy = false);
        },
        onWebResourceError: (err) {
          if (err.isForMainFrame != true) return;
          if (mounted) {
            setState(() {
              _busy = false;
              _failed = true;
            });
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  void _reload() {
    setState(() {
      _busy = true;
      _failed = false;
    });
    _ctrl.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1109),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8A4A18),
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          if (!_failed) WebViewWidget(controller: _ctrl),
          if (_failed)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.wifi_off_rounded,
                      color: Colors.white70, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Unable to load the page.\nCheck your connection and retry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          if (_busy && !_failed)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFE9A23C)),
            ),
        ],
      ),
    );
  }
}
