import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewPage extends StatefulWidget {
  const PaymentWebViewPage({super.key});
  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final url = args != null ? args['url'] as String? : null;

    return Scaffold(
      appBar: AppBar(
          title: const Text('بوابة الدفع'), backgroundColor: Colors.deepOrange),
      body: url == null
          ? const Center(child: Text('لا يوجد رابط دفع'))
          : WebViewWidget(controller: _controller..loadRequest(Uri.parse(url))),
    );
  }
}
