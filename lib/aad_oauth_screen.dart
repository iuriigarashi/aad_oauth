import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'helper/auth_storage.dart';
import 'model/config.dart';
import 'model/token.dart';
import 'request/authorization_request.dart';
import 'request_code.dart';
import 'request_token.dart';

class AadOauthScreen extends StatefulWidget {
  final String? title;
  String? url;

  final Config? config;
  AuthStorage? _authStorage;
  Token? _token;
  Widget? menu;
  RequestCode? _requestCode;
  RequestToken? _requestToken;
  late AuthorizationRequest _authorizationRequest;
  final CookieManager cookieManager = CookieManager();

  AadOauthScreen({
    Key? key,
    this.title,
    this.config,
  }) : super(key: key) {
    _authStorage = new AuthStorage(tokenIdentifier: config!.tokenIdentifier);
    _requestCode = new RequestCode(config!);
    _requestToken = new RequestToken(config);
    _authorizationRequest = new AuthorizationRequest(config!);
  }

  @override
  _AadOauthScreenState createState() => _AadOauthScreenState();
}

class _AadOauthScreenState extends State<AadOauthScreen> {
  final Completer<WebViewController> _controller =
      Completer<WebViewController>();

  bool isLoading = false;

  String? _userAgent = '<unknown>';
  String? _webUserAgent = '<unknown>';

  @override
  void initState() {
    widget.cookieManager.clearCookies();
    super.initState();
    //initUserAgentState();
  }

  Future<void> initUserAgentState() async {
    String? userAgent, webViewUserAgent;

    if (!mounted) return;

    setState(() {
      _userAgent = userAgent;
      _webUserAgent = webViewUserAgent;
    });
  }

  String _constructUrlParams() =>
      _mapToQueryParams(widget._authorizationRequest.parameters);

  String _mapToQueryParams(Map<String, String?> params) {
    final queryParams = <String>[];
    params
        .forEach((String key, String? value) => queryParams.add("$key=$value"));
    return queryParams.join("&");
  }

  String getUserAgent() {
    if (Platform.isIOS) {
      return "Mozilla/5.0 (iPhone; CPU iPhone OS 12_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1 Mobile/15E148 Safari/604.1";
    }
    return "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.117 Mobile Safari/537.36";
  }

  @override
  Widget build(BuildContext context) {
    widget.menu = SampleMenu(_controller.future);

    final String urlParams = _constructUrlParams();

    return Scaffold(
      appBar: AppBar(
        elevation: widget.config!.appbarElevation,
        title: Text(
          widget.config!.appbarTitle,
          style: TextStyle(
            color: widget.config!.appbarContentColor,
          ),
        ),
        backgroundColor: widget.config!.appbarColor,
        brightness: widget.config!.appbarBrightness,
        iconTheme: IconThemeData(
          color: widget.config!.appbarContentColor,
        ),
        actions: <Widget>[
          // NavigationControls(_controller.future),
          // widget.menu
        ],
      ),
      body: Stack(
        children: <Widget>[
          Builder(builder: (BuildContext context) {
            return WebView(
              initialUrl: Uri.encodeFull(
                  "${widget._authorizationRequest.url}?$urlParams"),
              userAgent: getUserAgent(),
              javascriptMode: JavascriptMode.unrestricted,
              onWebViewCreated: (WebViewController webViewController) {
                _controller.complete(webViewController);
              },
              javascriptChannels: <JavascriptChannel>[
                _toasterJavascriptChannel(context),
              ].toSet(),
              navigationDelegate: (NavigationRequest request) {
                // if (request.url.startsWith('https://www.youtube.com/')) {
                //   print('blocking navigation to $request}');
                //   return NavigationDecision.prevent;
                // }
                // print('allowing navigation to $request');
                return NavigationDecision.navigate;
              },
              onPageStarted: (String url) {
                print('Page started loading: $url');
                if (!isLoading) {
                  setState(() {
                    isLoading = true;
                  });
                }
              },
              onPageFinished: (String url) {
                print('Page finished loading: $url');

                Uri uri = Uri.parse(url);

                if (uri.queryParameters["error"] != null) {
                  // throw new Exception(
                  //     "Access denied or authentation canceled.");
                }

                if (url.contains(widget.config!.redirectUri!
                        .split("://")[1]
                        .split("/")[0]) &&
                    uri.queryParameters["code"] != null) {
                  var code = uri.queryParameters["code"]!;
                  print("code: " + code);

                  Navigator.pop(context, code);
                }

                setState(() {
                  isLoading = false;
                });
              },
              gestureNavigationEnabled: false,
            );
          }),
          isLoading
              ? SizedBox.expand(
                  child: Container(
                    color: widget.config!.loadingBodyColor,
                    child: Center(
                      child: Platform.isIOS
                          ? CupertinoActivityIndicator(
                              radius: 15,
                            )
                          : CircularProgressIndicator(),
                    ),
                  ),
                )
              : Container(),
        ],
      ),
    );
  }

  JavascriptChannel _toasterJavascriptChannel(BuildContext context) {
    return JavascriptChannel(
        name: 'Toaster',
        onMessageReceived: (JavascriptMessage message) {
          Scaffold.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        });
  }
}

class NavigationControls extends StatelessWidget {
  const NavigationControls(this._webViewControllerFuture)
      : assert(_webViewControllerFuture != null);

  final Future<WebViewController> _webViewControllerFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WebViewController>(
      future: _webViewControllerFuture,
      builder:
          (BuildContext context, AsyncSnapshot<WebViewController> snapshot) {
        final bool webViewReady =
            snapshot.connectionState == ConnectionState.done;
        final WebViewController? controller = snapshot.data;
        return Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: !webViewReady
                  ? null
                  : () async {
                      if (await controller!.canGoBack()) {
                        await controller.goBack();
                      } else {
                        Scaffold.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text("Nenhum item do histórico para voltar"),
                          ),
                        );
                        return;
                      }
                    },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: !webViewReady
                  ? null
                  : () async {
                      if (await controller!.canGoForward()) {
                        await controller.goForward();
                      } else {
                        Scaffold.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text("Nenhum item do histórico para avançar"),
                          ),
                        );
                        return;
                      }
                    },
            ),
            // IconButton(
            //   icon: const Icon(Icons.replay),
            //   onPressed: !webViewReady
            //       ? null
            //       : () {
            //           controller.reload();
            //         },
            // ),
          ],
        );
      },
    );
  }
}

enum MenuOptions {
  showUserAgent,
  listCookies,
  clearCookies,
  addToCache,
  listCache,
  clearCache,
  navigationDelegate,
}

class SampleMenu extends StatelessWidget {
  SampleMenu(this.controller);

  final Future<WebViewController> controller;
  final CookieManager cookieManager = CookieManager();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WebViewController>(
      future: controller,
      builder:
          (BuildContext context, AsyncSnapshot<WebViewController> controller) {
        return PopupMenuButton<MenuOptions>(
          onSelected: (MenuOptions value) {
            switch (value) {
              case MenuOptions.showUserAgent:
                _onShowUserAgent(controller.data!, context);
                break;
              case MenuOptions.listCookies:
                _onListCookies(controller.data!, context);
                break;
              case MenuOptions.clearCookies:
                onClearCookies(context);
                break;
              case MenuOptions.addToCache:
                _onAddToCache(controller.data!, context);
                break;
              case MenuOptions.listCache:
                _onListCache(controller.data!, context);
                break;
              case MenuOptions.clearCache:
                _onClearCache(controller.data!, context);
                break;
              case MenuOptions.navigationDelegate:
                _onNavigationDelegateExample(controller.data, context);
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuItem<MenuOptions>>[
            PopupMenuItem<MenuOptions>(
              value: MenuOptions.showUserAgent,
              child: const Text('Show user agent'),
              enabled: controller.hasData,
            ),
            const PopupMenuItem<MenuOptions>(
              value: MenuOptions.listCookies,
              child: Text('List cookies'),
            ),
            const PopupMenuItem<MenuOptions>(
              value: MenuOptions.clearCookies,
              child: Text('Clear cookies'),
            ),
            const PopupMenuItem<MenuOptions>(
              value: MenuOptions.addToCache,
              child: Text('Add to cache'),
            ),
            const PopupMenuItem<MenuOptions>(
              value: MenuOptions.listCache,
              child: Text('List cache'),
            ),
            const PopupMenuItem<MenuOptions>(
              value: MenuOptions.clearCache,
              child: Text('Clear cache'),
            ),
            const PopupMenuItem<MenuOptions>(
              value: MenuOptions.navigationDelegate,
              child: Text('Navigation Delegate example'),
            ),
          ],
        );
      },
    );
  }

  void _onShowUserAgent(
      WebViewController controller, BuildContext context) async {
    // Send a message with the user agent string to the Toaster JavaScript channel we registered
    // with the WebView.
    await controller.evaluateJavascript(
        'Toaster.postMessage("User Agent: " + navigator.userAgent);');
  }

  void _onListCookies(
      WebViewController controller, BuildContext context) async {
    final String cookies =
        await controller.evaluateJavascript('document.cookie');
    Scaffold.of(context).showSnackBar(SnackBar(
      content: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('Cookies:'),
          _getCookieList(cookies),
        ],
      ),
    ));
  }

  void _onAddToCache(WebViewController controller, BuildContext context) async {
    await controller.evaluateJavascript(
        'caches.open("test_caches_entry"); localStorage["test_localStorage"] = "dummy_entry";');
    Scaffold.of(context).showSnackBar(const SnackBar(
      content: Text('Added a test entry to cache.'),
    ));
  }

  void _onListCache(WebViewController controller, BuildContext context) async {
    await controller.evaluateJavascript('caches.keys()'
        '.then((cacheKeys) => JSON.stringify({"cacheKeys" : cacheKeys, "localStorage" : localStorage}))'
        '.then((caches) => Toaster.postMessage(caches))');
  }

  void _onClearCache(WebViewController controller, BuildContext context) async {
    await controller.clearCache();
    Scaffold.of(context).showSnackBar(const SnackBar(
      content: Text("Cache cleared."),
    ));
  }

  void onClearCookies(BuildContext context) async {
    final bool hadCookies = await cookieManager.clearCookies();
    String message = 'There were cookies. Now, they are gone!';
    if (!hadCookies) {
      message = 'There are no cookies.';
    }
    Scaffold.of(context).showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  void _onNavigationDelegateExample(
      WebViewController? controller, BuildContext context) async {
    //final String contentBase64 =
    //    base64Encode(const Utf8Encoder().convert(kNavigationExamplePage));
    //await controller.loadUrl('data:text/html;base64,$contentBase64');
  }

  Widget _getCookieList(String cookies) {
    if (cookies == null || cookies == '""') {
      return Container();
    }
    final List<String> cookieList = cookies.split(';');
    final Iterable<Text> cookieWidgets =
        cookieList.map((String cookie) => Text(cookie));
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: cookieWidgets.toList(),
    );
  }
}
