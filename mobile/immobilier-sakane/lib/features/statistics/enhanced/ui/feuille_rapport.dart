import 'package:flutter/material.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/features/statistics/enhanced/cubit/financial_stats_cubit.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

/// Ouvre le choix du rapport des statistiques : la période de l'écran,
/// le détail voulu et le format. Le fichier prêt est ouvert puis proposé
/// au partage.
Future<void> ouvrirFeuilleRapport(BuildContext context, FinancialStatsState state) async {
  final messager = ScaffoldMessenger.of(context);
  if (state.from == null || state.to == null) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FeuilleRapport(
      state: state,
      onPret: (chemin, format) => _montrerFichier(messager, chemin, format),
    ),
  );
}

Future<void> _montrerFichier(ScaffoldMessengerState messager, String chemin, String format) async {
  final ouverture = await OpenFile.open(chemin);
  final message = messager.showSnackBar(SnackBar(
    content: Text(ouverture.type == ResultType.done
        ? 'Rapport ${format == 'pdf' ? 'PDF' : 'Excel'} prêt.'
        : 'Aucune application pour ouvrir ce fichier : partagez-le.'),
    duration: const Duration(seconds: 5),
    action: SnackBarAction(
      label: 'Partager',
      onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(chemin)])),
    ),
  ));
  // Comme pour les exports : le message a bouton se ferme apres 5 secondes.
  Future.delayed(const Duration(seconds: 5), () {
    try {
      message.close();
    } catch (_) {}
  });
}

class _FeuilleRapport extends StatefulWidget {
  final FinancialStatsState state;
  final void Function(String chemin, String format) onPret;

  const _FeuilleRapport({required this.state, required this.onPret});

  @override
  State<_FeuilleRapport> createState() => _FeuilleRapportState();
}

class _FeuilleRapportState extends State<_FeuilleRapport> {
  static const _texte = Color(0xFF17262E);
  static const _gris = Color(0xFF6B7B84);

  bool _anneeEntiere = false;
  bool _detail = true;
  String _format = 'pdf';
  bool _enCours = false;
  String? _erreur;

  /// Les appartements que le rapport couvrira. Vide = tous.
  final Set<int> _biensChoisis = <int>{};
  List<_BienChoix> _biensDispo = const [];
  bool _chargementBiens = false;

  @override
  void initState() {
    super.initState();
    _biensDispo = (widget.state.stats?.comparative ?? const [])
        .map((c) => _BienChoix(c.id, c.title))
        .toList();
    if (_biensDispo.isEmpty && !widget.state.singlePropertyMode) _chargerBiens();
  }

  /// Les statistiques n'ont rien renvoye : on demande la liste des
  /// appartements au serveur pour pouvoir proposer le choix.
  Future<void> _chargerBiens() async {
    setState(() => _chargementBiens = true);
    try {
      final biens = await Dependencies.get<Repository>().getRealestates();
      if (!mounted) return;
      setState(() {
        _biensDispo = biens
            .where((b) => b.id != null)
            .map((b) => _BienChoix(
                b.id!, (b.title ?? '').trim().isEmpty ? 'Bien ${b.id}' : b.title!.trim()))
            .toList();
        _chargementBiens = false;
      });
    } catch (_) {
      if (mounted) setState(() => _chargementBiens = false);
    }
  }

  DateTime get _debutEcran => widget.state.from!;
  DateTime get _finEcran => widget.state.to!;

  DateTime get _du => _anneeEntiere ? DateTime(_debutEcran.year, 1, 1) : _debutEcran;
  DateTime get _au => _anneeEntiere ? DateTime(_debutEcran.year, 12, 31) : _finEcran;

  /// La période de l'écran couvre déjà l'année entière.
  bool get _dejaAnnee =>
      _memeJour(_debutEcran, DateTime(_debutEcran.year, 1, 1)) &&
      _memeJour(_finEcran, DateTime(_debutEcran.year, 12, 31));

  static bool _memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<int> get _biens => widget.state.singlePropertyMode
      ? widget.state.selectedRealestateIds
      : _biensChoisis.toList();

  String _nomBien(int id, {String? defaut}) {
    for (final b in _biensDispo) {
      if (b.id == id) return b.titre;
    }
    return defaut ?? 'Bien $id';
  }

  /// Ce que le rapport couvrira, en une ligne.
  String get _resumeBiens {
    if (widget.state.singlePropertyMode) {
      final ids = widget.state.selectedRealestateIds;
      return ids.isEmpty
          ? 'Le bien de cette page'
          : _nomBien(ids.first, defaut: 'Le bien de cette page');
    }
    if (_biensChoisis.isEmpty) return 'Tous les appartements';
    if (_biensChoisis.length == 1) return _nomBien(_biensChoisis.first);
    return '${_biensChoisis.length} appartements choisis';
  }

  Future<void> _choisirBiens() async {
    final choix = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ChoixBiens(biens: _biensDispo, choisis: _biensChoisis),
    );
    if (choix == null || !mounted) return;
    setState(() {
      _biensChoisis
        ..clear()
        ..addAll(choix);
    });
  }

  /// La ligne qui montre les appartements retenus et ouvre leur choix.
  Widget _ligneBiens() {
    final primaire = AppColors.primaryColor;
    final bienUnique = widget.state.singlePropertyMode;
    final sansListe = !bienUnique && _biensDispo.isEmpty;
    final actif = !bienUnique && !sansListe && !_enCours;

    final String sousTitre;
    if (bienUnique) {
      sousTitre = '$_resumeBiens • cette page ne montre que ce bien';
    } else if (_chargementBiens) {
      sousTitre = 'Chargement de la liste des appartements…';
    } else if (sansListe) {
      sousTitre = "La liste des appartements n'est pas disponible : le rapport "
          'couvrira tous les appartements.';
    } else {
      sousTitre = _resumeBiens;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8EC)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        enabled: actif,
        onTap: actif ? _choisirBiens : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primaire.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.apartment_outlined, size: 20, color: primaire),
        ),
        title: const Text('Appartements du rapport',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _texte)),
        subtitle: Text(sousTitre,
            style: const TextStyle(fontSize: 12, height: 1.3, color: _gris)),
        trailing: _chargementBiens
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : actif
                ? const Icon(Icons.chevron_right, color: Color(0xFF98A6AE))
                : null,
      ),
    );
  }

  Future<void> _telecharger() async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final chemin = await Dependencies.get<Repository>().telechargerRapportStatistiques(
        du: _du,
        au: _au,
        biens: _biens,
        repartition: widget.state.repartition,
        detail: _detail,
        format: _format,
      );
      if (mounted) Navigator.of(context).pop();
      widget.onPret(chemin, _format);
    } on NetworkConnectivityException {
      _echec('Pas de connexion. Vérifiez le réseau puis réessayez.');
    } on UnAuthenticatedException {
      if (mounted) Navigator.of(context).pop();
      logout();
    } on UnAuthorizedException {
      _echec("Vous n'avez pas le droit de télécharger ce rapport.");
    } catch (e) {
      _echec(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _echec(String message) {
    if (!mounted) return;
    setState(() {
      _enCours = false;
      _erreur = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaire = AppColors.primaryColor;
    final nuit = widget.state.repartition == 'nuit';

    return PopScope(
      canPop: !_enCours,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5DDE2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Télécharger le rapport',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _texte)),
              const SizedBox(height: 14),

              // Période
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaire.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primaire.withValues(alpha: .25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_outlined, size: 19, color: primaire),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Du ${dateExport(_du)} au ${dateExport(_au)}',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold, color: _texte)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Le rapport reprend la période choisie sur l'écran. Pour un autre "
                      'mois, une année ou une période, changez-la avec le sélecteur de période.',
                      style: TextStyle(fontSize: 12.5, height: 1.35, color: _gris),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_resumeBiens'
                      ' • ${nuit ? 'argent réparti par nuit' : "argent à l'encaissement"}',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A5B64)),
                    ),
                  ],
                ),
              ),
              if (!_dejaAnnee) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Cette période'),
                      selected: !_anneeEntiere,
                      onSelected: _enCours ? null : (_) => setState(() => _anneeEntiere = false),
                    ),
                    ChoiceChip(
                      label: Text("Toute l'année ${_debutEcran.year}"),
                      selected: _anneeEntiere,
                      onSelected: _enCours ? null : (_) => setState(() => _anneeEntiere = true),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              // Appartements couverts
              _ligneBiens(),
              const SizedBox(height: 14),

              // Détail
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8EC)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SwitchListTile(
                  value: _detail,
                  onChanged: _enCours ? null : (v) => setState(() => _detail = v),
                  activeThumbColor: Colors.white,
                  activeTrackColor: primaire,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: const Text('Détail par mois et par appartement',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _texte)),
                  subtitle: const Text(
                    'Pour chaque mois de la période : les chiffres de chaque appartement '
                    'et la liste des écritures.',
                    style: TextStyle(fontSize: 12, height: 1.3, color: _gris),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Format
              const Text('Format',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _texte)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _CaseFormat(
                      icone: Icons.picture_as_pdf_outlined,
                      titre: 'PDF',
                      detail: 'Document à imprimer',
                      couleur: const Color(0xFFB3261E),
                      choisi: _format == 'pdf',
                      onTap: _enCours ? null : () => setState(() => _format = 'pdf'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CaseFormat(
                      icone: Icons.table_chart_outlined,
                      titre: 'Excel',
                      detail: 'Tableur .xlsx',
                      couleur: const Color(0xFF1E7B45),
                      choisi: _format == 'xlsx',
                      onTap: _enCours ? null : () => setState(() => _format = 'xlsx'),
                    ),
                  ),
                ],
              ),

              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, size: 19, color: Color(0xFFB3261E)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_erreur!,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF8C1D18))),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _enCours ? null : _telecharger,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaire,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primaire.withValues(alpha: .6),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _enCours
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(_enCours ? 'Préparation du rapport…' : 'Télécharger',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaseFormat extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String detail;
  final Color couleur;
  final bool choisi;
  final VoidCallback? onTap;

  const _CaseFormat({
    required this.icone,
    required this.titre,
    required this.detail,
    required this.couleur,
    required this.choisi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: choisi ? couleur.withValues(alpha: .10) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: choisi ? couleur : const Color(0xFFD5DDE2),
              width: choisi ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icone, size: 28, color: couleur),
              const SizedBox(height: 6),
              Text(titre,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: couleur)),
              const SizedBox(height: 2),
              Text(detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF4A5B64))),
            ],
          ),
        ),
      ),
    );
  }
}


class _BienChoix {
  final int id;
  final String titre;

  const _BienChoix(this.id, this.titre);
}

/// Le choix des appartements couverts par le rapport : recherche,
/// cases a cocher, rien de coche = tous les appartements.
class _ChoixBiens extends StatefulWidget {
  final List<_BienChoix> biens;
  final Set<int> choisis;

  const _ChoixBiens({required this.biens, required this.choisis});

  @override
  State<_ChoixBiens> createState() => _ChoixBiensState();
}

class _ChoixBiensState extends State<_ChoixBiens> {
  static const _texte = Color(0xFF17262E);
  static const _gris = Color(0xFF6B7B84);

  final _recherche = TextEditingController();
  late final Set<int> _choisis = {...widget.choisis};

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  static String _sansAccents(String s) {
    const avec = 'àâäáãéèêëíìîïóòôöõúùûüçñ';
    const sans = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = avec.indexOf(ch);
      b.write(i < 0 ? ch : sans[i]);
    }
    return b.toString();
  }

  List<_BienChoix> get _visibles {
    final q = _sansAccents(_recherche.text.trim());
    if (q.isEmpty) return widget.biens;
    return widget.biens.where((b) => _sansAccents(b.titre).contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaire = AppColors.primaryColor;
    final visibles = _visibles;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5DDE2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Appartements du rapport',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold, color: _texte)),
                    const SizedBox(height: 4),
                    Text(
                      _choisis.isEmpty
                          ? 'Aucun choix : le rapport couvrira tous les appartements.'
                          : '${_choisis.length} appartement${_choisis.length > 1 ? 's' : ''} '
                              'sur ${widget.biens.length}',
                      style: const TextStyle(fontSize: 12.5, height: 1.3, color: _gris),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _recherche,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Rechercher un appartement',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _recherche.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(() => _recherche.clear()),
                              ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD5DDE2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD5DDE2)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(() {
                            _choisis
                              ..clear()
                              ..addAll(widget.biens.map((b) => b.id));
                          }),
                          child: const Text('Tout sélectionner'),
                        ),
                        TextButton(
                          onPressed: () => setState(_choisis.clear),
                          child: const Text('Aucun'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8EC)),
              Expanded(
                child: visibles.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Aucun appartement ne correspond à cette recherche.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: _gris)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: visibles.length,
                        itemBuilder: (_, i) {
                          final bien = visibles[i];
                          return CheckboxListTile(
                            value: _choisis.contains(bien.id),
                            onChanged: (coche) => setState(() {
                              if (coche ?? false) {
                                _choisis.add(bien.id);
                              } else {
                                _choisis.remove(bien.id);
                              }
                            }),
                            activeColor: primaire,
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            title: Text(bien.titre,
                                style: const TextStyle(fontSize: 14, color: _texte)),
                          );
                        },
                      ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8EC)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_choisis),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaire,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Valider',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
