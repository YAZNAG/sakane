import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/repository/repository.dart';

/// Ce que l'utilisateur décide face à un client déjà enregistré.
class ChoixDoublon {
  /// Le client existant choisi ; nul si l'on crée quand même un nouveau client.
  final Client? existant;
  const ChoixDoublon(this.existant);
}

/// Cherche un client déjà enregistré avec le même téléphone, la même CIN
/// ou le même nom. S'il y en a, propose de reprendre son dossier.
///
/// Renvoie nul si l'utilisateur annule, [ChoixDoublon] avec le client
/// existant s'il le choisit, ou [ChoixDoublon] vide pour créer quand même.
/// Sans réseau, on ne bloque pas la création.
Future<ChoixDoublon?> verifierClientExistant(
  BuildContext context, {
  String? tel,
  String? cin,
  String? prenom,
  String? nom,
}) async {
  List<Map<String, dynamic>> trouves;
  try {
    trouves = await Dependencies.get<Repository>()
        .chercherDoublonsClient(tel: tel, cin: cin, prenom: prenom, nom: nom);
  } catch (_) {
    return const ChoixDoublon(null);
  }
  if (trouves.isEmpty || !context.mounted) return const ChoixDoublon(null);

  return showDialog<ChoixDoublon>(
    context: context,
    builder: (ctx) => _DialogueDoublons(trouves: trouves),
  );
}

class _DialogueDoublons extends StatelessWidget {
  final List<Map<String, dynamic>> trouves;

  const _DialogueDoublons({required this.trouves});

  static String _date(dynamic iso) {
    final d = DateTime.tryParse((iso ?? '').toString());
    if (d == null) return '-';
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${deux(d.day)}/${deux(d.month)}/${d.year}';
  }

  static const _libellesRaisons = {
    'telephone': 'Même téléphone',
    'cin': 'Même CIN',
    'nom': 'Même nom',
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      title: const Row(
        children: [
          Icon(Icons.person_search, color: Color(0xFFD97E1A)),
          SizedBox(width: 8),
          Expanded(
            child: Text('Client déjà enregistré',
                style: TextStyle(fontSize: 17, color: Color(0xFF17262E))),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trouves.length == 1
                    ? 'Ce client existe déjà. Choisissez son dossier plutôt que d\'en créer un doublon.'
                    : '${trouves.length} clients ressemblent à celui-ci. Choisissez le bon dossier plutôt que d\'en créer un doublon.',
                style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF28414F)),
              ),
              const SizedBox(height: 12),
              ...trouves.map((j) {
                final client = Client.fromJson(j);
                final nomFr = [client.firstName, client.lastName].whereType<String>().join(' ').trim();
                final nomAr = [client.firstNameAr, client.lastNameAr].whereType<String>().join(' ').trim();
                final raisons = ((j['raisons'] as List?) ?? const []).map((e) => e.toString()).toList();
                final nb = (j['nbReservations'] as num?)?.toInt() ?? 0;
                final derniere = j['derniereReservation'] as Map?;

                Widget ligne(IconData icone, String texte) => Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          Icon(icone, size: 14, color: const Color(0xFF6B7B84)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(texte,
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF28414F))),
                          ),
                        ],
                      ),
                    );

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8EE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF3D9B1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nomFr.isEmpty ? 'Client n° ${client.id}' : nomFr,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF17262E))),
                      if (nomAr.isNotEmpty)
                        Text(nomAr,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF4A5B64))),
                      if (client.listeNoire != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.block, size: 15, color: Color(0xFFC62828)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Client sur liste noire : ${client.listeNoire!.motif ?? 'motif non précisé'}',
                                  style: const TextStyle(
                                      fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFC62828)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: raisons
                            .map((r) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97E1A).withValues(alpha: .15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(_libellesRaisons[r] ?? r,
                                      style: const TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA8542B))),
                                ))
                            .toList(),
                      ),
                      if ((client.tel ?? '').isNotEmpty) ligne(Icons.phone_outlined, client.tel!),
                      if ((client.identityNumber ?? '').isNotEmpty)
                        ligne(Icons.badge_outlined, 'CIN ${client.identityNumber}'),
                      if ((client.email ?? '').isNotEmpty && !(client.email!.endsWith('@gmail.com') && client.email!.contains(RegExp(r'\d{9,}'))))
                        ligne(Icons.mail_outline, client.email!),
                      ligne(Icons.event_note_outlined,
                          '$nb réservation${nb > 1 ? 's' : ''}'
                          '${derniere == null ? '' : ' • dernière : ${derniere['bien'] ?? ''} (${_date(derniere['checkin'])})'}'),
                      if (j['creeLe'] != null) ligne(Icons.schedule, 'Client depuis le ${_date(j['creeLe'])}'),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(ChoixDoublon(client)),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Choisir ce client'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(const ChoixDoublon(null)),
          child: const Text('Créer quand même'),
        ),
      ],
    );
  }
}
