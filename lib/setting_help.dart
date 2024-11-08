import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class HelpSupportPage extends StatefulWidget {
  @override
  _HelpSupportPageState createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Help & Support", 
        style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          )),
        backgroundColor: Color(0xFFA81B60)
        ,
      ),
      body: ListView(
        children: [
          // Using custom SettingsTile
          SettingsTile(
            icon: Icons.support_agent,
            title: 'Contact Us',
            onTap: () async {
              final String url = 'https://wa.me/60197656575';
              if (await canLaunch(url)) {
                await launch(url);
              } else {
                throw 'Could not launch $url';
              }
            },
          ),
          Divider(),

          SettingsTile(
            icon: Icons.settings,
            title: 'Privacy Policy',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WebViewPage(
                    url: 'https://youbaby.my/privacypolicy/',
                  ),
                ),
              );
            },
          ),
          Divider(),

          SettingsTile(
            icon: Icons.help,
            title: 'Refund and Return Policy',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WebViewPage(
                    url: 'https://youbaby.my/returnandrefundpolicy/',
                  ),
                ),
              );
            },
          ),
          Divider(),

          SettingsTile(
            icon: Icons.info,
            title: 'About App',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AboutAppPage(),
                ),
              );
            },
          ),
          Divider(),
        ],
      ),
    );
  }
}

class WebViewPage extends StatefulWidget {
  final String url;

  WebViewPage({required this.url});

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? webViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Web View"),
        backgroundColor: Color(0xFFA81B60),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(widget.url),
        ),
        onWebViewCreated: (controller) {
          webViewController = controller;
        },
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            javaScriptEnabled: true,
          ),
        ),
      ),
    );
  }
}

class AboutAppPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('About App'),
        backgroundColor: Color(0xFFA81B60),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Youbaby Parenting Apps',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 18),
              Text(
                'Version: 1.0.0',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              SizedBox(
                height: 100,
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: 20),
              Text(
                '© 2017 - 2024 Youbaby Million Sdn. Bhd.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  SettingsTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFFA81B60)),
      title: Text(title),
      trailing: Icon(Icons.arrow_forward_ios),
      onTap: onTap,
    );
  }
}
