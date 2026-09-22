import 'package:flutter/material.dart';
import 'package:immobilier/core/utils/droits.dart';

/// Droit « Supprimer une campagne » : le serveur répond 403 sans lui,
/// l'action est donc masquée.
bool suppressionCampagneAutorisee() => peut(AppPermission.deleteCampaign);

/// Droit « Lancer / mettre en pause / annuler » une campagne.
bool gestionCampagneAutorisee() => peut(AppPermission.manageCampaign);

/// Droit « Créer une campagne » (création, estimation, envoi test).
bool creationCampagneAutorisee() => peut(AppPermission.createCampaign);

/// Elements visuels partages par les ecrans de campagnes.
class CampagneUi {
  static const texte = Color(0xFF17262E);
  static const gris = Color(0xFF6B7B84);
  static const grisClair = Color(0xFF98A6AE);
  static const bordure = Color(0xFFE2E8EC);
  static const fond = Color(0xFFF5F7F9);

  static const vert = Color(0xFF1E7B45);
  static const rouge = Color(0xFFB3261E);
  static const orange = Color(0xFFE07B00);
  static const bleu = Color(0xFF1565C0);
  static const sarcelle = Color(0xFF00897B);
  static const ardoise = Color(0xFF607D8B);

  /// Couleur de fond des bulles WhatsApp.
  static const bulle = Color(0xFFDCF8C6);

  // Specifique a l'application : format de numero et exemple de lien.
  static const numeroTestExemple = "212600000000";
  static const numeroTestAide = "Format international (212…).";
  static const lienAide = "Ajouté à la fin du message.";

  static String? validerLien(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final u = Uri.tryParse(v.trim());
    return (u != null && u.hasScheme && u.hasAuthority)
        ? null
        : "Lien invalide (commencez par https://)";
  }

  static Color couleurStatut(String statut) {
    switch (statut) {
      case 'programmee':
        return bleu;
      case 'en_cours':
        return vert;
      case 'en_pause':
        return orange;
      case 'terminee':
        return sarcelle;
      case 'annulee':
        return rouge;
      default:
        return ardoise;
    }
  }

  static IconData iconeStatut(String statut) {
    switch (statut) {
      case 'programmee':
        return Icons.schedule_rounded;
      case 'en_cours':
        return Icons.send_rounded;
      case 'en_pause':
        return Icons.pause_rounded;
      case 'terminee':
        return Icons.done_all_rounded;
      case 'annulee':
        return Icons.block_rounded;
      default:
        return Icons.edit_note_rounded;
    }
  }

  static String deux(int n) => n.toString().padLeft(2, '0');

  static String heure(DateTime d) => "${deux(d.hour)}h${deux(d.minute)}";

  /// "Aujourd'hui à 14h05", "Hier à 09h10" ou "12/09/2026 à 18h00".
  static String dateHeure(DateTime d) {
    final maintenant = DateTime.now();
    final jour = DateTime(d.year, d.month, d.day);
    final aujourdhui =
        DateTime(maintenant.year, maintenant.month, maintenant.day);
    final ecart = aujourdhui.difference(jour).inDays;
    if (ecart == 0) return "Aujourd'hui à ${heure(d)}";
    if (ecart == 1) return "Hier à ${heure(d)}";
    if (ecart == -1) return "Demain à ${heure(d)}";
    return "${deux(d.day)}/${deux(d.month)}/${d.year} à ${heure(d)}";
  }

  /// "il y a 30 s", "il y a 4 min", sinon la date complete.
  static String depuis(DateTime d) {
    final ecart = DateTime.now().difference(d);
    if (ecart.isNegative || ecart.inSeconds < 60) {
      return "il y a ${ecart.isNegative ? 0 : ecart.inSeconds} s";
    }
    if (ecart.inMinutes < 60) return "il y a ${ecart.inMinutes} min";
    return dateHeure(d).replaceFirst("Aujourd'hui", "aujourd'hui");
  }

  /// "8 min", "1 h 05", "2 h".
  static String duree(int minutes) {
    if (minutes < 1) return "moins d'1 min";
    if (minutes < 60) return "$minutes min";
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? "$h h" : "$h h ${deux(m)}";
  }

  static String pluriel(int n, String singulier, [String? pluriel]) =>
      "$n ${n > 1 ? (pluriel ?? '${singulier}s') : singulier}";

  /// Premier message d'une erreur 422 : le serveur explique pourquoi
  /// l'action est refusee (statut incompatible, etc.).
  static String premiereErreur(Map<String, dynamic>? erreurs,
      [String defaut = "Données invalides"]) {
    if (erreurs == null || erreurs.isEmpty) return defaut;
    final premiere = erreurs['statut'] ?? erreurs['msg'] ?? erreurs.values.first;
    if (premiere is List && premiere.isNotEmpty) return premiere.first.toString();
    return premiere.toString();
  }

  static BoxDecoration carte({Color? couleurBord}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: couleurBord ?? bordure),
      );
}

/// Pastille de statut. "En cours" porte un point qui pulse.
class StatutCampagneChip extends StatelessWidget {
  final String statut;
  final String libelle;
  final bool grand;

  const StatutCampagneChip({
    super.key,
    required this.statut,
    required this.libelle,
    this.grand = false,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = CampagneUi.couleurStatut(statut);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: grand ? 12 : 10, vertical: grand ? 6 : 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statut == 'en_cours')
            PointPulsant(couleur: couleur)
          else
            Icon(CampagneUi.iconeStatut(statut),
                size: grand ? 15 : 13, color: couleur),
          SizedBox(width: grand ? 6 : 5),
          Text(
            libelle,
            style: TextStyle(
              fontSize: grand ? 13 : 11.5,
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}

/// Petit point anime : l'envoi avance en ce moment.
class PointPulsant extends StatefulWidget {
  final Color couleur;
  final double taille;

  const PointPulsant({super.key, required this.couleur, this.taille = 8});

  @override
  State<PointPulsant> createState() => _PointPulsantState();
}

class _PointPulsantState extends State<PointPulsant>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.taille;
    return SizedBox(
      width: t * 2,
      height: t * 2,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final v = Curves.easeOut.transform(_anim.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: t + t * v,
                height: t + t * v,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.couleur.withValues(alpha: .35 * (1 - v)),
                ),
              ),
              Container(
                width: t,
                height: t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.couleur,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Barre d'avancement arrondie.
class BarreCampagne extends StatelessWidget {
  final double valeur;
  final Color couleur;
  final double hauteur;

  const BarreCampagne({
    super.key,
    required this.valeur,
    required this.couleur,
    this.hauteur = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(hauteur),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: valeur),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => LinearProgressIndicator(
          value: v,
          minHeight: hauteur,
          backgroundColor: const Color(0xFFE9EEF1),
          valueColor: AlwaysStoppedAnimation<Color>(couleur),
        ),
      ),
    );
  }
}

/// Dialogue de confirmation clair : titre, explication, action colorée.
Future<bool> confirmerCampagne(
  BuildContext context, {
  required String titre,
  required String message,
  required String confirmer,
  required IconData icone,
  Color couleur = CampagneUi.bleu,
  String retour = "Retour",
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: .12),
          shape: BoxShape.circle,
        ),
        child: Icon(icone, color: couleur, size: 27),
      ),
      title: Text(titre,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: CampagneUi.texte)),
      content: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 14, height: 1.4, color: CampagneUi.gris)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: CampagneUi.texte,
                  side: const BorderSide(color: CampagneUi.bordure),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(retour),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  backgroundColor: couleur,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(confirmer,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return ok == true;
}

/// Demande le numero qui recevra le message test.
Future<String?> demanderNumeroTest(BuildContext context) async {
  final controleur = TextEditingController();
  final numero = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Envoi test",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Le message sera envoyé à ce numéro avec des valeurs d'exemple "
            "pour les variables. Aucun client ne le recevra.",
            style: TextStyle(fontSize: 13, height: 1.35, color: CampagneUi.gris),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controleur,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: "Numéro WhatsApp",
              hintText: CampagneUi.numeroTestExemple,
              helperText: CampagneUi.numeroTestAide,
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.phone_iphone_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text("Annuler"),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(ctx).pop(controleur.text.trim()),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text("Envoyer le test"),
        ),
      ],
    ),
  );
  // Pas de dispose : le champ vit encore pendant l'animation de fermeture.
  return (numero == null || numero.isEmpty) ? null : numero;
}
