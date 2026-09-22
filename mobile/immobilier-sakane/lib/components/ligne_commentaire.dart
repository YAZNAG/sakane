import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

/// Le commentaire saisi avec une opération de caisse : un apport, un
/// transfert, un encaissement…
///
/// Une ligne secondaire, en italique, précédée d'une bulle. Rien n'est
/// affiché quand le commentaire est vide. Un texte en arabe s'écrit de
/// droite à gauche.
class LigneCommentaire extends StatelessWidget {
  final String? texte;
  final double taille;
  final Color? couleur;
  final EdgeInsetsGeometry marge;

  const LigneCommentaire(
    this.texte, {
    super.key,
    this.taille = 12,
    this.couleur,
    this.marge = const EdgeInsets.only(top: 4),
  });

  static bool aContenu(String? texte) =>
      texte != null && texte.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!aContenu(texte)) return const SizedBox.shrink();

    final t = texte!.trim();
    final rtl = intl.Bidi.detectRtlDirectionality(t);
    final c = couleur ?? Colors.grey.shade700;

    return Padding(
      padding: marge,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.chat_bubble_outline, size: taille, color: c),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              t,
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              textAlign: TextAlign.start,
              softWrap: true,
              style: TextStyle(
                fontSize: taille,
                height: 1.35,
                fontStyle: FontStyle.italic,
                color: c,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
