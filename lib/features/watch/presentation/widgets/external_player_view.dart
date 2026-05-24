import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Renders an external (embed) room inside a WebView. Cross-origin players run
/// autonomously, so we can't seek them — instead the WebView reloads whenever
/// [resyncTick] / [url] change (a "Resync" press or a source switch), bringing
/// every viewer back to the authoritative position at the cost of one reload.
class ExternalPlayerView extends StatefulWidget {
  const ExternalPlayerView({super.key, required this.url, required this.resyncTick});

  final String url;
  final int resyncTick;

  @override
  State<ExternalPlayerView> createState() => _ExternalPlayerViewState();
}

class _ExternalPlayerViewState extends State<ExternalPlayerView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void didUpdateWidget(ExternalPlayerView old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _controller.loadRequest(Uri.parse(widget.url));
    } else if (old.resyncTick != widget.resyncTick) {
      _controller.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: WebViewWidget(controller: _controller),
    );
  }
}
