/// Un bien retire des listes (desactive), tel que rendu par
/// `POST /realestates/{id}/desactiver`, `.../reactiver` et `GET /biens-desactives`.
class BienDesactive {
  final int id;
  final String? titre;
  final bool desactive;
  final DateTime? desactiveLe;
  final String? desactivePar;
  final String? motif;

  const BienDesactive({
    required this.id,
    this.titre,
    this.desactive = true,
    this.desactiveLe,
    this.desactivePar,
    this.motif,
  });

  factory BienDesactive.fromJson(Map<String, dynamic> json) {
    final par = json['desactivePar'];
    String? nomPar;
    if (par is Map) {
      nomPar = (par['name'] ?? par['nom'])?.toString();
    } else if (par != null) {
      nomPar = par.toString();
    }
    final le = json['desactiveLe'];
    final motif = json['motif']?.toString();
    return BienDesactive(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      titre: (json['titre'] ?? json['title'])?.toString(),
      desactive: json['desactive'] == true || json['desactive'] == 1,
      desactiveLe: le is String ? DateTime.tryParse(le) : null,
      desactivePar: (nomPar ?? '').isEmpty ? null : nomPar,
      motif: (motif ?? '').trim().isEmpty ? null : motif,
    );
  }
}
