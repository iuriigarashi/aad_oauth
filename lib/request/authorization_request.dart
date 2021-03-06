
import 'package:aad_oauth/model/config.dart';

class AuthorizationRequest {

  String? url;
  String? redirectUrl;
  late Map<String, String?> parameters;
  Map<String, String>? headers;
  bool? fullScreen;
  late bool clearCookies;

  AuthorizationRequest(Config config,
      {bool fullScreen: true, bool clearCookies: false}) {
    this.url = config.authorizationUrl;
    this.redirectUrl = config.redirectUri;
    this.parameters = {
      "client_id": config.clientId,
      "response_type": config.responseType,
      "redirect_uri": config.redirectUri,
      "scope": config.scope
    };

    if(config.isB2C){
      parameters.addAll({
        "p": config.userFlow,
        "nonce": config.nonce,
        "response_mode": "query",
      });
    }

    this.fullScreen = fullScreen;
    this.clearCookies = clearCookies;
  }
}
