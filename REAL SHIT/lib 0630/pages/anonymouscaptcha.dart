import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AnonymousCaptchaPage extends StatefulWidget {
  const AnonymousCaptchaPage({Key? key}) : super(key: key);

  @override
  _AnonymousCaptchaPageState createState() => _AnonymousCaptchaPageState();
}

class _AnonymousCaptchaPageState extends State<AnonymousCaptchaPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..loadRequest(Uri.parse(
          'file:///android_asset/flutter_assets/assets/captcha.html'));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: SizedBox(
        height: 400,
        width: 300,
        child: Column(
          children: [
            AppBar(
              title: const Text('Captcha Verification'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}
