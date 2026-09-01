import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 이용약관·개인정보 처리방침을 앱 안에서 보여준다.
/// iOS 가 시트로 웹뷰를 띄우는 것과 같은 동작이다(브라우저로 나가지 않는다).
class WebPage extends StatefulWidget {
  const WebPage({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
