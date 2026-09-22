import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:immobilier/core/offline/synchronisation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:immobilier/core/offline/coupure_reseau.dart';

/// Conserve la derniere reponse reussie de chaque consultation, et la
/// restitue lorsque le reseau fait defaut.
///
/// Place en interception du client HTTP, ce mecanisme s'applique a toutes
/// les listes de l'application sans avoir a les modifier une par une.
class CacheLecture extends Interceptor {
  static const _dossierCache = 'cache_lecture';

  /// Au dela de cette anciennete, une donnee n'est plus proposee :
  /// mieux vaut un ecran vide qu'un planning faux.
  static const _validite = Duration(days: 7);

  Directory? _dossier;

  Future<Directory> get _racine async {
    if (_dossier != null) return _dossier!;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/$_dossierCache');
    if (!await d.exists()) await d.create(recursive: true);
    return _dossier = d;
  }

  /// Nom de fichier stable et sans caractere interdit, derive de l'appel.
  String _cle(RequestOptions options) {
    final requete = StringBuffer(options.path);
    final parametres = options.queryParameters;
    if (parametres.isNotEmpty) {
      final cles = parametres.keys.toList()..sort();
      for (final k in cles) {
        requete.write('|$k=${parametres[k]}');
      }
    }
    // Empreinte simple : suffisante pour distinguer deux appels.
    var empreinte = 0;
    for (final unite in requete.toString().codeUnits) {
      empreinte = (empreinte * 31 + unite) & 0x7fffffff;
    }
    final lisible = options.path
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${lisible.isEmpty ? 'racine' : lisible}_$empreinte.json';
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final options = response.requestOptions;

    // Un telechargement de fichier n'a rien a faire dans un cache de
    // lectures JSON : son corps est un flux, l'encoder echouerait, et
    // l'attente inutile retarde la consommation du flux.
    final estJson = options.responseType == ResponseType.json;

    if (estJson &&
        options.method.toUpperCase() == 'GET' &&
        (response.statusCode ?? 0) == 200) {
      try {
        final f = File('${(await _racine).path}/${_cle(options)}');
        await f.writeAsString(jsonEncode({
          'enregistreLe': DateTime.now().toIso8601String(),
          'donnees': response.data,
        }));
      } catch (_) {
        // Un cache indisponible ne doit jamais empecher l'affichage.
      }
    }

    if ((response.statusCode ?? 0) == 200) {
      Synchronisation.instance.signalerSucces();
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;

    final coupure = estCoupureReseau(err);

    if (options.responseType != ResponseType.json ||
        options.method.toUpperCase() != 'GET' ||
        !coupure) {
      if (coupure) Synchronisation.instance.signalerCoupure();
      return handler.next(err);
    }

    Synchronisation.instance.signalerCoupure();

    try {
      final f = File('${(await _racine).path}/${_cle(options)}');
      if (await f.exists()) {
        final contenu = jsonDecode(await f.readAsString());
        final enregistreLe =
            DateTime.tryParse(contenu['enregistreLe'] ?? '') ?? DateTime(2000);

        if (DateTime.now().difference(enregistreLe) <= _validite) {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: contenu['donnees'],
            // Permet a l'appelant de savoir que la donnee vient du telephone.
            headers: Headers.fromMap({
              'x-donnees-locales': ['1'],
              'x-enregistre-le': [enregistreLe.toIso8601String()],
            }),
          ));
        }
      }
    } catch (_) {
      // Cache illisible : on laisse remonter l'erreur reseau d'origine.
    }

    handler.next(err);
  }

  /// Efface les donnees consultees, par exemple a la deconnexion.
  static Future<void> vider() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final d = Directory('${base.path}/$_dossierCache');
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {
      // Sans consequence.
    }
  }
}
