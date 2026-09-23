import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/apercu_commun.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/models/apercu_famille.dart';

/// Ce qu'une carte du jour annonce : une arrivée ou un départ.
enum SensDuJour { arrivee, depart }

/// La pastille de paiement d'un séjour, choisie par le serveur.
///
/// Un séjour Airbnb ne s'encaisse pas ici : sa pastille le dit plutôt
/// que d'annoncer un reste dû qui n'existe pas dans cette caisse.
PastillePaiement pastilleDe(SejourDuJour s) {
  if (s.estAirbnb) {
    return const PastillePaiement(libelle: 'Airbnb', teinte: rougeAccueil);
  }
  if (s.estPaye) {
    return const PastillePaiement(libelle: 'Payé', teinte: vertAccueil);
  }
  if (s.estPartiel) {
    return const PastillePaiement(libelle: 'Partiel', teinte: bleuCharte);
  }
  final reste = s.reste > 0 ? s.reste : s.montant;
  return PastillePaiement(
    libelle: reste > 0 ? 'Reste ${montantAccueil(reste)}' : 'Non payé',
    teinte: orangeAccueil,
  );
}

/// Une arrivée ou un départ du jour : l'heure, le bien, le client, l'état
/// du paiement, et le bouton qui confirme le passage.
///
/// Le bouton est sous la carte, pleine largeur : c'est le geste du jour,
/// il ne se cherche pas. Il disparaît sans le droit correspondant, et
/// pour un séjour Airbnb, qui se confirme du côté d'Airbnb.
class CarteSejourDuJour extends StatelessWidget {
  final SejourDuJour sejour;
  final SensDuJour sens;

  /// Null : le bouton de confirmation n'est pas affiché.
  final VoidCallback? onConfirmer;

  /// Ouverture du détail de la réservation (appui sur la carte).
  final VoidCallback? onOuvrir;

  /// Vrai pendant une confirmation : les boutons ne répondent plus.
  final bool enCours;

  const CarteSejourDuJour({
    super.key,
    required this.sejour,
    required this.sens,
    this.onConfirmer,
    this.onOuvrir,
    this.enCours = false,
  });

  bool get _arrivee => sens == SensDuJour.arrivee;

  @override
  Widget build(BuildContext context) {
    final teinteHeure = _arrivee ? AppColors.primaryColor : orangeAccueil;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(rayonAccueil),
            child: InkWell(
              onTap: onOuvrir,
              borderRadius: BorderRadius.circular(rayonAccueil),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: bordureAccueil),
                  borderRadius: BorderRadius.circular(rayonAccueil),
                  boxShadow: ombreAccueil,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    BlocHeure(
                      heure: sejour.heure,
                      libelle: _arrivee ? 'arrivée' : 'départ',
                      teinte: teinteHeure,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _identite()),
                    const SizedBox(width: 8),
                    pastilleDe(sejour),
                  ],
                ),
              ),
            ),
          ),
          if (onConfirmer != null) ...[
            const SizedBox(height: 8),
            _bouton(),
          ],
        ],
      ),
    );
  }

  Widget _identite() {
    final nuits = sejour.nuits;
    final detail = nuits > 0
        ? '$nuits nuit${nuits > 1 ? 's' : ''}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          sejour.bien.isEmpty ? 'Bien' : sejour.bien,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 14.5, fontWeight: FontWeight.w800, color: texteAccueil),
        ),
        const SizedBox(height: 2),
        if (sejour.estAirbnb)
          // Un séjour lu sur Airbnb n'a pas de client chez nous : son
          // code de réservation le désigne.
          Text(
            'Séjour Airbnb · ${sejour.airbnb}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: texteDouxAccueil),
          )
        else
          NomClient(
            nom: [
              sejour.client.isEmpty ? 'Client' : sejour.client,
              if (detail != null) detail,
            ].join(' · '),
            nomArabe: sejour.clientAr,
            style: const TextStyle(fontSize: 12.5, color: texteDouxAccueil),
          ),
      ],
    );
  }

  Widget _bouton() {
    final libelle = _arrivee ? "Confirmer l'arrivée" : 'Confirmer le départ';
    final action = enCours ? null : onConfirmer;

    if (_arrivee) {
      return SizedBox(
        height: 44,
        child: ElevatedButton(
          onPressed: action,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primaryColor.withValues(alpha: .5),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(libelle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      );
    }
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: action,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryColor,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.primaryColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(libelle,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// L'esquisse d'une carte du jour, le temps de la lecture.
class SqueletteSejour extends StatelessWidget {
  const SqueletteSejour({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: CarteAccueil(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            BlocSquelette(hauteur: 44, largeur: 58, rayon: 12),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BlocSquelette(hauteur: 13, largeur: 140),
                  SizedBox(height: 7),
                  BlocSquelette(hauteur: 11, largeur: 100),
                ],
              ),
            ),
            SizedBox(width: 8),
            BlocSquelette(hauteur: 22, largeur: 56, rayon: 11),
          ],
        ),
      ),
    );
  }
}
