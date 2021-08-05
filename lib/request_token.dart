import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart';
import 'model/config.dart';
import 'request/token_refresh_request.dart';
import 'request/token_request.dart';
import 'model/token.dart';

class RequestToken {
  final Config? config;
  late TokenRequestDetails _tokenRequest;
  late TokenRefreshRequestDetails _tokenRefreshRequest;

  RequestToken(this.config);

  Future<Token> requestToken(String? code) async {
    _generateTokenRequest(code);
    final uri = Uri.parse(_tokenRequest.url!);
    return await _sendTokenRequest(uri, _tokenRequest.params, _tokenRequest.headers);
  }

  Future<Token> requestRefreshToken(String? refreshToken) async  {
    _generateTokenRefreshRequest(refreshToken);
    final uri = Uri.parse(_tokenRefreshRequest.url!);
    return await _sendTokenRequest(uri, _tokenRefreshRequest.params, _tokenRefreshRequest.headers);
  }

  Future<Token> _sendTokenRequest(Uri url, Map<String, String?>? params, Map<String, String>? headers) async {
    Response response = await post(url,
        body: params,
        headers: headers);
    Map<String, dynamic>? tokenJson = json.decode(response.body);
    Token token = new Token.fromJson(tokenJson);
    return token;
  }

  void _generateTokenRequest(String? code) {
    _tokenRequest = new TokenRequestDetails(config!, code);
  }

  void _generateTokenRefreshRequest(String? refreshToken) {
    _tokenRefreshRequest = new TokenRefreshRequestDetails(config!, refreshToken);
  }  
}