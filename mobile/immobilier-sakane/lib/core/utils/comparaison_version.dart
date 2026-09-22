/// Comparaison de deux numeros de version de la forme "9.7.0".
///
/// Renvoie un nombre negatif si [a] precede [b], zero si les deux
/// versions sont equivalentes, un nombre positif si [a] est plus
/// recente.
///
/// Les numeros absents valent zero : "9.7" et "9.7.0" sont equivalents.
/// Une valeur illisible est traitee comme zero plutot que de faire
/// echouer la comparaison : mieux vaut ne pas proposer de mise a jour
/// que d'empecher l'acces a l'application.
int comparerVersions(String? a, String? b) {
  final gauche = _nombres(a);
  final droite = _nombres(b);
  final longueur = gauche.length > droite.length ? gauche.length : droite.length;

  for (var i = 0; i < longueur; i++) {
    final g = i < gauche.length ? gauche[i] : 0;
    final d = i < droite.length ? droite[i] : 0;
    if (g != d) return g - d;
  }
  return 0;
}

/// Vrai seulement si le serveur propose une version plus recente que
/// celle installee.
bool miseAJourDisponible({
  required String? versionServeur,
  required String versionInstallee,
}) {
  return comparerVersions(versionServeur, versionInstallee) > 0;
}

List<int> _nombres(String? version) {
  if (version == null || version.trim().isEmpty) return const [0];
  return version
      .trim()
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}
