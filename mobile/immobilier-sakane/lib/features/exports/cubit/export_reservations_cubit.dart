import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:dio/dio.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';

/// Ce sur quoi porte l'export : des biens, ou des clients.
enum AxeExport { biens, clients }

class ExportReservationsState {
  final AppStatus chargement;
  final AppStatus exportation;

  final List<Realestate> biens;
  final List<Client> clients;

  /// Identifiants cochés, par axe. Les deux sélections coexistent :
  /// on peut préparer l'une puis revenir à l'autre sans tout perdre.
  final Set<int> biensChoisis;
  final Set<int> clientsChoisis;

  final AxeExport axe;
  final String recherche;
  final DateTime? du;
  final DateTime? au;

  /// Chemin du fichier produit, une fois l'export abouti.
  final String? fichier;
  final String? erreur;

  const ExportReservationsState({
    this.chargement = AppStatus.unknown,
    this.exportation = AppStatus.unknown,
    this.biens = const [],
    this.clients = const [],
    this.biensChoisis = const {},
    this.clientsChoisis = const {},
    this.axe = AxeExport.biens,
    this.recherche = '',
    this.du,
    this.au,
    this.fichier,
    this.erreur,
  });

  /// Nombre d'éléments cochés sur l'axe courant.
  int get nbChoisis =>
      axe == AxeExport.biens ? biensChoisis.length : clientsChoisis.length;

  /// Sans rien de coché, l'export porte sur tout ce que l'agent peut voir.
  bool get toutExporter => biensChoisis.isEmpty && clientsChoisis.isEmpty;

  List<Realestate> get biensFiltres {
    if (recherche.isEmpty) return biens;
    final q = recherche.toLowerCase();
    return biens
        .where((b) => (b.title ?? '').toLowerCase().contains(q))
        .toList();
  }

  List<Client> get clientsFiltres {
    if (recherche.isEmpty) return clients;
    final q = recherche.toLowerCase();
    return clients.where((c) {
      final nom = "${c.firstName ?? ''} ${c.lastName ?? ''} ${c.tel ?? ''}";
      return nom.toLowerCase().contains(q);
    }).toList();
  }

  ExportReservationsState copyWith({
    AppStatus? chargement,
    AppStatus? exportation,
    List<Realestate>? biens,
    List<Client>? clients,
    Set<int>? biensChoisis,
    Set<int>? clientsChoisis,
    AxeExport? axe,
    String? recherche,
    DateTime? du,
    DateTime? au,
    bool viderDates = false,
    String? fichier,
    String? erreur,
  }) {
    return ExportReservationsState(
      chargement: chargement ?? this.chargement,
      exportation: exportation ?? this.exportation,
      biens: biens ?? this.biens,
      clients: clients ?? this.clients,
      biensChoisis: biensChoisis ?? this.biensChoisis,
      clientsChoisis: clientsChoisis ?? this.clientsChoisis,
      axe: axe ?? this.axe,
      recherche: recherche ?? this.recherche,
      du: viderDates ? null : (du ?? this.du),
      au: viderDates ? null : (au ?? this.au),
      fichier: fichier,
      erreur: erreur,
    );
  }
}

class ExportReservationsCubit extends Cubit<ExportReservationsState> {
  ExportReservationsCubit() : super(const ExportReservationsState());

  Repository get _repository => Dependencies.get<Repository>();

  Future<void> charger() async {
    emit(state.copyWith(chargement: AppStatus.loading));
    try {
      // Les deux listes sont chargées d'un coup : l'agent bascule
      // d'un axe à l'autre sans attendre.
      final resultats = await Future.wait([
        _repository.getRealestates(),
        _repository.getClients(),
      ]);

      emit(state.copyWith(
        chargement: AppStatus.success,
        biens: resultats[0] as List<Realestate>,
        clients: resultats[1] as List<Client>,
      ));
    } catch (ex) {
      emit(state.copyWith(chargement: AppStatus.error, erreur: ex.toString()));
    }
  }

  void changerAxe(AxeExport axe) =>
      emit(state.copyWith(axe: axe, recherche: ''));

  void rechercher(String q) => emit(state.copyWith(recherche: q));

  void basculerBien(int id) {
    final choisis = Set<int>.from(state.biensChoisis);
    choisis.contains(id) ? choisis.remove(id) : choisis.add(id);
    emit(state.copyWith(biensChoisis: choisis));
  }

  void basculerClient(int id) {
    final choisis = Set<int>.from(state.clientsChoisis);
    choisis.contains(id) ? choisis.remove(id) : choisis.add(id);
    emit(state.copyWith(clientsChoisis: choisis));
  }

  /// Coche ou décoche tout ce que le filtre laisse voir — jamais ce qui
  /// est masqué, qu'on décocherait sans s'en apercevoir.
  void toutBasculer() {
    if (state.axe == AxeExport.biens) {
      final visibles =
          state.biensFiltres.map((b) => b.id).whereType<int>().toSet();
      final choisis = Set<int>.from(state.biensChoisis);
      final tousCoches = visibles.every(choisis.contains);
      tousCoches ? choisis.removeAll(visibles) : choisis.addAll(visibles);
      emit(state.copyWith(biensChoisis: choisis));
    } else {
      final visibles =
          state.clientsFiltres.map((c) => c.id).whereType<int>().toSet();
      final choisis = Set<int>.from(state.clientsChoisis);
      final tousCoches = visibles.every(choisis.contains);
      tousCoches ? choisis.removeAll(visibles) : choisis.addAll(visibles);
      emit(state.copyWith(clientsChoisis: choisis));
    }
  }

  void effacerSelection() => emit(state.copyWith(
        biensChoisis: const {},
        clientsChoisis: const {},
      ));

  void definirPeriode(DateTime? du, DateTime? au) {
    if (du == null && au == null) {
      emit(state.copyWith(viderDates: true));
      return;
    }
    emit(state.copyWith(du: du, au: au));
  }

  Future<void> exporter(String format) async {
    emit(state.copyWith(exportation: AppStatus.loading));
    try {
      final chemin = await _repository.exportReservations(
        format: format,
        realestateIds: state.biensChoisis.toList(),
        clientIds: state.clientsChoisis.toList(),
        du: state.du,
        au: state.au,
      );
      emit(state.copyWith(exportation: AppStatus.success, fichier: chemin));
    } catch (ex) {
      emit(state.copyWith(exportation: AppStatus.error, erreur: _raison(ex)));
    }
  }

  /// Une phrase que l'agent peut suivre, plutot qu'une trace technique.
  ///
  /// « Export impossible » ne dit pas s'il faut retrouver du reseau,
  /// demander un droit, ou signaler un defaut.
  static String _raison(Object ex) {
    if (ex is NetworkConnectivityException) {
      return "Pas de connexion. L'export a besoin du reseau : "
          "reessayez une fois le reseau revenu.";
    }
    if (ex is UnAuthenticatedException) {
      return "Votre session a expire. Reconnectez-vous, puis reessayez.";
    }
    if (ex is UnAuthorizedException) {
      return "Votre compte n'a pas le droit d'exporter les reservations.";
    }

    final texte = ex.toString();
    if (ex is DioException) {
      final code = ex.response?.statusCode;
      if (code != null) {
        return "Le serveur a repondu $code. Signalez-le si cela se repete.";
      }
      if (ex.type == DioExceptionType.receiveTimeout ||
          ex.type == DioExceptionType.sendTimeout) {
        return "Le serveur a mis trop de temps a repondre. "
            "Restreignez la selection ou la periode, puis reessayez.";
      }
      return "Echec du telechargement : ${ex.type.name}.";
    }

    return texte.length > 160 ? "${texte.substring(0, 160)}…" : texte;
  }
}
