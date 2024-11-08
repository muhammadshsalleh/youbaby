import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  InAppWebViewController? webViewController;
  bool isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     backgroundColor: const Color(0xFFA91B60),
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://youbabyglobal.com/'),
              ),
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() {
                  isLoading = true;
                });
              },
              onLoadStop: (controller, url) {
                setState(() {
                  isLoading = false;
                });
              },
              initialOptions: InAppWebViewGroupOptions(
                crossPlatform: InAppWebViewOptions(
                  javaScriptEnabled: true,
                ),
              ),
            ),
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA91B60)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}