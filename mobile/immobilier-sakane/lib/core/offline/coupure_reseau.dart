import 'dart:io';

import 'package:dio/dio.dart';

/// La seule regle de l'application pour reconnaitre une coupure reseau.
///
/// Sont des coupures : pas de reseau, Wi-Fi sans internet, serveur
/// injoignable, connexion interrompue, delai depasse. Une reponse du
/// serveur, meme une erreur, n'en est jamais une.
bool estCoupureReseau(DioException ex) {
  if (ex.response != null) return false;
  if (ex.error is SocketException ||
      ex.error is HttpException ||
      ex.error is HandshakeException ||
      ex.error is TlsException) {
    return true;
  }
  switch (ex.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      return true;
    default:
      return false;
  }
}
