/// Les groupes WhatsApp à qui l'agence peut écrire.
///
/// WhatsApp ne désigne pas un groupe par un numéro mais par un identifiant
/// de la forme « 120363089069041137@g.us ». Un lien d'invitation ne suffit
/// donc pas : le serveur le traduit en identifiant, et fait rejoindre le
/// groupe au numéro de l'agence — on ne peut pas écrire dans un groupe que
/// l'on n'a pas rejoint.
library;

class GroupeWhatsapp {
  final int id;
  final String nom;
  final String jid;
  final String? lien;
  final bool actif;

  /// Le nombre de membres, tel que la dernière vérification l'a vu.
  final int? participants;
  final DateTime? verifieLe;

  /// Combien de syndics reçoivent dans ce groupe.
  final int syndics;

  const GroupeWhatsapp({
    required this.id,
    required this.nom,
    required this.jid,
    this.lien,
    this.actif = true,
    this.participants,
    this.verifieLe,
    this.syndics = 0,
  });

  factory GroupeWhatsapp.fromJson(Map<String, dynamic> json) => GroupeWhatsapp(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nom: json['nom']?.toString() ?? '',
        jid: json['jid']?.toString() ?? '',
        lien: json['lien']?.toString(),
        actif: json['actif'] != false,
        participants: (json['participants'] as num?)?.toInt(),
        verifieLe: DateTime.tryParse(json['verifieLe']?.toString() ?? '')?.toLocal(),
        syndics: (json['syndics'] as num?)?.toInt() ?? 0,
      );
}

/// Un groupe que le numéro de l'agence voit sur WhatsApp sans qu'il soit
/// encore enregistré : il suffit de le choisir.
class GroupeDisponible {
  final String jid;
  final String nom;
  final String? image;

  const GroupeDisponible({required this.jid, required this.nom, this.image});

  factory GroupeDisponible.fromJson(Map<String, dynamic> json) => GroupeDisponible(
        jid: json['jid']?.toString() ?? '',
        nom: json['nom']?.toString() ?? '',
        image: json['image']?.toString(),
      );
}

class GroupesWhatsapp {
  final List<GroupeWhatsapp> groupes;
  final List<GroupeDisponible> disponibles;

  const GroupesWhatsapp({this.groupes = const [], this.disponibles = const []});

  factory GroupesWhatsapp.fromJson(Map<String, dynamic> reponse) {
    final data = (reponse['data'] as Map<String, dynamic>?) ?? reponse;
    return GroupesWhatsapp(
      groupes: ((data['groupes'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => GroupeWhatsapp.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      disponibles: ((data['disponibles'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => GroupeDisponible.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  List<GroupeWhatsapp> get actifs => groupes.where((g) => g.actif).toList();
}

/// Le groupe où un syndic reçoit, tel que la fiche du syndic le porte.
class GroupeDuSyndic {
  final int id;
  final String nom;
  final bool actif;

  const GroupeDuSyndic({required this.id, required this.nom, this.actif = true});

  factory GroupeDuSyndic.fromJson(Map<String, dynamic> json) => GroupeDuSyndic(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nom: json['nom']?.toString() ?? '',
        actif: json['actif'] != false,
      );
}
