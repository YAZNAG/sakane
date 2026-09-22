/// Un contrat signé avec un propriétaire, joint pour l'un de ses appartements.
class ContratProprietaire {
  final int id;
  final int? proprietaireId;
  final int? bienId;
  final String? bien;
  final String? titre;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final String url;
  final String? nomFichier;
  final String? typeMime;
  final int? taille;
  final DateTime? creeLe;
  final String? par;

  const ContratProprietaire({
    required this.id,
    this.proprietaireId,
    this.bienId,
    this.bien,
    this.titre,
    this.dateDebut,
    this.dateFin,
    required this.url,
    this.nomFichier,
    this.typeMime,
    this.taille,
    this.creeLe,
    this.par,
  });

  bool get estPdf =>
      (typeMime ?? '').contains('pdf') || url.toLowerCase().endsWith('.pdf');

  factory ContratProprietaire.fromJson(Map<String, dynamic> json) {
    return ContratProprietaire(
      id: (json['id'] as num?)?.toInt() ?? 0,
      proprietaireId: (json['proprietaireId'] as num?)?.toInt(),
      bienId: (json['bienId'] as num?)?.toInt(),
      bien: json['bien']?.toString(),
      titre: json['titre']?.toString(),
      dateDebut: DateTime.tryParse((json['dateDebut'] ?? '').toString()),
      dateFin: DateTime.tryParse((json['dateFin'] ?? '').toString()),
      url: (json['url'] ?? '').toString(),
      nomFichier: json['nomFichier']?.toString(),
      typeMime: json['typeMime']?.toString(),
      taille: (json['taille'] as num?)?.toInt(),
      creeLe: DateTime.tryParse((json['creeLe'] ?? '').toString())?.toLocal(),
      par: json['par']?.toString(),
    );
  }
}
