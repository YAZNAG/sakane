import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/models/resume_accueil.dart';

/// La caisse, sur l'accueil : ce que l'agent doit avoir sur lui.
///
/// C'est le premier chiffre de la journée, donc le plus gros de l'écran.
/// Le détail — encaissé, sorti, à remettre — vient après, en trois
/// colonnes, parce qu'il explique le solde sans le remplacer.
class CarteCaisseAccueil extends StatelessWidget {
  final CaisseResume caisse;

  /// Encaisser : nul lorsque le droit manque, le bouton disparaît alors.
  final VoidCallback? onEncaisser;

  /// Ouvre le module Caisse.
  final VoidCallback onOuvrirModule;

  /// L'ouverture de la caisse, quand elle est fermée.
  final VoidCallback onOuvrirCaisse;

  const CarteCaisseAccueil({
    super.key,
    required this.caisse,
    required this.onOuvrirModule,
    required this.onOuvrirCaisse,
    this.onEncaisser,
  });

  Widget _entete() {
    final numero = caisse.numero;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              numero == null ? caisse.nom : '${caisse.nom} · n° $numero',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: texteDouxAccueil,
                fontFeatures: chiffresTabulaires,
              ),
            ),
          ),
        ),
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.account_balance_wallet_outlined,
              size: 18, color: AppColors.primaryColor),
        ),
      ],
    );
  }

  Widget _colonne(String libelle, String valeur, Color teinte) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: texteDouxAccueil),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valeur,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: teinte,
                fontFeatures: chiffresTabulaires,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!caisse.ouverte) return _fermee();

    return CarteAccueil(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _entete(),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              montantAccueil(caisse.solde),
              style: TextStyle(
                fontSize: 34,
                height: 1.05,
                fontWeight: FontWeight.bold,
                letterSpacing: -.8,
                color: caisse.solde < 0 ? rougeAccueil : texteAccueil,
                fontFeatures: chiffresTabulaires,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ce que vous devez avoir sur vous',
            style: TextStyle(fontSize: 12, color: texteDouxAccueil),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: bordureAccueil),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _colonne('Encaissé', '+${montantAccueil(caisse.encaisse, avecDevise: false)}',
                  vertAccueil),
              _colonne('Sorties', '−${montantAccueil(caisse.sorties, avecDevise: false)}',
                  rougeAccueil),
              _colonne('À remettre',
                  montantAccueil(caisse.aRemettre, avecDevise: false), orangeAccueil),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (onEncaisser != null) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEncaisser,
                    icon: const Icon(Icons.south_west, size: 17),
                    label: const Text('Encaisser', style: TextStyle(fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: onOuvrirModule,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryColor,
                    side: const BorderSide(color: bordureAccueil),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Ouvrir la caisse',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Caisse fermée : rien à compter, une seule chose à faire.
  Widget _fermee() {
    return CarteAccueil(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _entete(),
          const SizedBox(height: 10),
          const Text(
            'Caisse fermée',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: texteAccueil,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caisse.aRemettre > 0.005
                ? 'Dernière clôture : ${montantAccueil(caisse.aRemettre)} à reporter.'
                : "Ouvrez votre caisse pour encaisser aujourd'hui.",
            style: const TextStyle(
                fontSize: 12, height: 1.3, color: texteDouxAccueil),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOuvrirCaisse,
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('Ouvrir ma caisse',
                  style: TextStyle(fontSize: 13.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
