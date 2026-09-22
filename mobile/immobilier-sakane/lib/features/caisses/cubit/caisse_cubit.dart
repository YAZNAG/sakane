import 'dart:io';
import 'package:immobilier/core/utils/droits.dart';

import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/caisses/cubit/caisse_airbnb_cubit.dart';
import 'package:immobilier/models/caisse.dart';
import 'package:immobilier/repository/repository.dart';

class CaisseState {
  final AppStatus chargement;
  final AppStatus action;

  /// La caisse de l'agent connecté.
  final MaCaisse? maCaisse;

  /// Les caisses de tout le monde : renseigné pour l'administrateur.
  final List<SoldeCaisse> caisses;

  /// Les caisses vers lesquelles on peut transférer.
  final List<CaisseDestinataire> destinataires;
  final List<RemiseEnAttente> aConfirmer;
  final double enTransit;

  /// Les caisses successives, chacune avec son journal : rien ne
  /// disparait apres une cloture.
  final List<SessionCaisse> sessions;

  /// La caisse Airbnb : chargée pour l'administrateur seulement.
  final CaisseAirbnb? caisseAirbnb;

  final String? message;
  final String? erreur;

  const CaisseState({
    this.chargement = AppStatus.unknown,
    this.action = AppStatus.unknown,
    this.maCaisse,
    this.caisses = const [],
    this.destinataires = const [],
    this.aConfirmer = const [],
    this.enTransit = 0,
    this.sessions = const [],
    this.caisseAirbnb,
    this.message,
    this.erreur,
  });

  /// Vrai lorsque le compte voit les caisses des autres.
  bool get estAdmin => caisses.isNotEmpty || aConfirmer.isNotEmpty;

  CaisseState copyWith({
    AppStatus? chargement,
    AppStatus? action,
    MaCaisse? maCaisse,
    List<SoldeCaisse>? caisses,
    List<CaisseDestinataire>? destinataires,
    List<RemiseEnAttente>? aConfirmer,
    List<SessionCaisse>? sessions,
    double? enTransit,
    CaisseAirbnb? caisseAirbnb,
    String? message,
    String? erreur,
  }) {
    return CaisseState(
      chargement: chargement ?? this.chargement,
      action: action ?? this.action,
      maCaisse: maCaisse ?? this.maCaisse,
      caisses: caisses ?? this.caisses,
      destinataires: destinataires ?? this.destinataires,
      aConfirmer: aConfirmer ?? this.aConfirmer,
      enTransit: enTransit ?? this.enTransit,
      sessions: sessions ?? this.sessions,
      caisseAirbnb: caisseAirbnb ?? this.caisseAirbnb,
      message: message,
      erreur: erreur,
    );
  }
}

class CaisseCubit extends Cubit<CaisseState> {
  CaisseCubit() : super(const CaisseState());

  Repository get _repository => Dependencies.get<Repository>();

  Future<void> charger() async {
    emit(state.copyWith(chargement: AppStatus.loading));
    try {
      final maCaisse = await _repository.maCaisse();

      // Chacun ne voit que sa propre caisse : plus de vue d'ensemble.
      // Toutes ses caisses successives s'affichent, pour que rien ne
      // disparaisse apres une cloture.
      List<SessionCaisse> sessions = const [];
      try {
        sessions = await _repository.sessionsCaisse();
      } catch (_) {
        // L'historique manquant n'empeche pas d'afficher le solde.
      }

      // Le gerant, qui tient la caisse principale, suit aussi celles des
      // autres. Pour tout autre utilisateur, la liste reste vide.
      List<SoldeCaisse> caisses = const [];
      if (peut(AppPermission.viewAllCashboxes)) {
        try {
          caisses = (await _repository.toutesLesCaisses()).caisses;
        } catch (_) {
          // La liste manquante n'empeche pas d'afficher sa propre caisse.
        }
      }

      // Les caisses vers lesquelles transferer : chacun peut envoyer
      // des especes a un collegue ou a l'agence.
      List<CaisseDestinataire> destinataires = const [];
      try {
        destinataires = await _repository.destinatairesCaisse();
      } catch (_) {
        // Sans la liste, le transfert ira a la caisse de l'agence.
      }

      // La caisse Airbnb n'est demandee que par l'administrateur : les
      // autres ne l'appellent jamais.
      CaisseAirbnb? caisseAirbnb;
      if (estAdminCaisseAirbnb) {
        try {
          caisseAirbnb = await _repository.caisseAirbnb();
        } catch (_) {
          // Sans elle, le reste de l'ecran s'affiche quand meme.
        }
      }

      emit(state.copyWith(
        chargement: AppStatus.success,
        maCaisse: maCaisse,
        caisseAirbnb: caisseAirbnb,
        caisses: caisses,
        destinataires: destinataires,
        aConfirmer: const [],
        enTransit: 0,
        sessions: sessions,
      ));
    } catch (ex) {
      emit(state.copyWith(chargement: AppStatus.error, erreur: ex.toString()));
    }
  }

  /// Ouvre une nouvelle caisse : soit en reportant ce qu'il restait,
  /// soit avec un fond saisi.
  Future<void> ouvrir({double? montant, bool reporter = false}) async {
    await _agir(
      () => _repository.ouvrirCaisse(montant: montant, reporter: reporter),
      reporter ? "Nouvelle caisse ouverte avec le report" : "Caisse ouverte",
    );
  }

  /// Envoie des espèces à une autre caisse.
  ///
  /// L'argent quitte la caisse aussitôt ; il n'entre chez le
  /// destinataire qu'après sa confirmation.
  Future<void> declarerRemise(
    double montant,
    String? commentaire, {
    int? caisse,
    File? piece,
  }) async {
    await _agir(
      () => _repository.declarerRemise(montant, commentaire,
          caisse: caisse, piece: piece),
      "Transfert annoncé : la somme quittera votre caisse à la confirmation",
    );
  }

  Future<void> confirmerRemise(int id, double montantRecu, String? commentaire) async {
    await _agir(
      () => _repository.confirmerRemise(id, montantRecu, commentaire),
      "Transfert confirmé : la somme est entrée dans votre caisse",
    );
  }

  /// Le solde qu'un client règle après coup : sans cette entrée, de
  /// l'argent reçu resterait hors de la caisse.
  Future<void> encaisserSolde(double montant, String? commentaire) async {
    await _agir(
      () => _repository.mouvementCaisse(
          sens: "entree",
          montant: montant,
          motif: "encaissement_solde",
          commentaire: commentaire),
      "Encaissement enregistré",
    );
  }

  /// Une sortie qui ne correspond à aucune charge saisie.
  Future<void> depenseDiverse(double montant, String? commentaire) async {
    await _agir(
      () => _repository.mouvementCaisse(
          sens: "sortie",
          montant: montant,
          motif: "depense_diverse",
          commentaire: commentaire),
      "Dépense enregistrée",
    );
  }

  Future<void> ajouterApport(double montant, String? commentaire) async {
    await _agir(
      () => _repository.mouvementCaisse(
          sens: "entree", montant: montant, motif: "apport", commentaire: commentaire),
      "Apport enregistré",
    );
  }

  /// Ramène une caisse à zéro. Le journal reste : un mouvement
  /// inverse annule le solde, la trace de l'opération est conservée.
  /// Le comptage de fin de journée : l'agent déclare ses espèces.
  Future<void> cloturer(double montantCompte, String? commentaire) async {
    emit(state.copyWith(action: AppStatus.loading));
    try {
      final c = await _repository.cloturerCaisse(montantCompte, commentaire);

      // Le message dit ce qui a été constaté : un comptage juste et un
      // manquant de 150 MAD ne s'annoncent pas de la même façon.
      final message = c.juste
          ? "Caisse clôturée — comptage juste"
          : (c.excedent
              ? "Clôturée — excédent de ${c.ecart.abs().toStringAsFixed(2)} MAD, ajouté à la caisse"
              : "Clôturée — manquant de ${c.ecart.abs().toStringAsFixed(2)} MAD, enregistré");

      emit(state.copyWith(action: AppStatus.success, message: message));
      await charger();
    } catch (ex) {
      emit(state.copyWith(action: AppStatus.error, erreur: _raison(ex)));
    }
  }

  Future<void> viderCaisse(int id, String motif) async {
    await _agir(
      () => _repository.viderCaisse(id, motif),
      "Caisse ramenée à zéro",
    );
  }

  Future<void> _agir(Future<void> Function() action, String succes) async {
    emit(state.copyWith(action: AppStatus.loading));
    try {
      await action();
      emit(state.copyWith(action: AppStatus.success, message: succes));
      // Le solde a bougé : on le relit plutôt que de le deviner.
      await charger();
    } catch (ex) {
      emit(state.copyWith(action: AppStatus.error, erreur: _raison(ex)));
    }
  }

  /// Le serveur refuse parfois pour une raison que l'agent doit lire :
  /// caisse déjà ouverte, remise supérieure au solde, droit manquant.
  static String _raison(Object ex) {
    final texte = ex.toString().replaceFirst("Exception: ", "");
    return texte.length > 160 ? "${texte.substring(0, 160)}…" : texte;
  }
}
