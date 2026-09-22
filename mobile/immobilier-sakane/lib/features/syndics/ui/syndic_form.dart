import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/syndics/cubit/syndic_form_cubit.dart';
import 'package:immobilier/features/syndics/ui/components/syndic_commun.dart';
import 'package:immobilier/models/syndic.dart';
import 'package:toastification/toastification.dart';

/// Création ([syndic] nul) ou modification d'un syndic et de ses biens.
class SyndicFormPage extends StatefulWidget {
  final Syndic? syndic;

  const SyndicFormPage({super.key, this.syndic});

  static Widget page({Syndic? syndic}) => BlocProvider(
        create: (_) => SyndicFormCubit()..chargerBiens(),
        child: SyndicFormPage(syndic: syndic),
      );

  @override
  State<SyndicFormPage> createState() => _SyndicFormPageState();
}

class _SyndicFormPageState extends State<SyndicFormPage> {
  final _formulaire = GlobalKey<FormState>();
  late final TextEditingController _nom;
  late final TextEditingController _telephone;
  late final TextEditingController _notes;
  final TextEditingController _recherche = TextEditingController();
  late bool _actif;
  late final Set<int> _choisis;
  String _texte = '';
  String? _erreurServeur;

  bool get _modification => widget.syndic != null;

  @override
  void initState() {
    super.initState();
    final s = widget.syndic;
    _nom = TextEditingController(text: s?.nom ?? '');
    _telephone = TextEditingController(text: s?.telephone ?? '');
    _notes = TextEditingController(text: s?.notes ?? '');
    _actif = s?.actif ?? true;
    _choisis = {...?s?.biens.map((b) => b.id)};
    _recherche.addListener(() {
      if (_recherche.text != _texte) setState(() => _texte = _recherche.text);
    });
  }

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    _notes.dispose();
    _recherche.dispose();
    super.dispose();
  }

  /// Les autres syndics du bien (hors celui qu'on édite) : un bien peut en
  /// avoir plusieurs, l'ajouter ici ne le retire pas des autres.
  List<String> _autresSyndics(BienDuSyndic b) => b.syndics
      .where((s) => s.id != widget.syndic?.id && s.nom.isNotEmpty)
      .map((s) => s.nom)
      .toList();

  void _enregistrer() {
    FocusScope.of(context).unfocus();
    setState(() => _erreurServeur = null);
    if (!(_formulaire.currentState?.validate() ?? false)) return;
    final notes = _notes.text.trim();
    context.read<SyndicFormCubit>().enregistrer(
          id: widget.syndic?.id,
          nom: _nom.text.trim(),
          telephone: chiffresTelephone(_telephone.text),
          actif: _actif,
          notes: notes.isEmpty ? null : notes,
          biens: _choisis.toList(),
        );
  }

  InputDecoration _decoration(String libelle, {String? indice, String? aide, IconData? icone}) {
    return InputDecoration(
      labelText: libelle,
      hintText: indice,
      helperText: aide,
      helperMaxLines: 2,
      prefixIcon: icone == null ? null : Icon(icone),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SyndicFormCubit, SyndicFormState>(
      listener: (context, state) {
        if (state.saveStatus == AppStatus.success && state.enregistre != null) {
          showToast(_modification ? 'Syndic modifié' : 'Syndic créé', context, second: 2);
          GoRouter.of(context).pop(state.enregistre);
        } else if (state.saveStatus == AppStatus.error) {
          setState(() => _erreurServeur = state.error);
          showToast('', context,
              description: state.error ?? "L'enregistrement a échoué",
              type: ToastificationType.error,
              second: 3);
        }
      },
      builder: (context, state) {
        final enCours = state.saveStatus == AppStatus.loading;
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              _modification ? 'Modifier le syndic' : 'Nouveau syndic',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryColor,
            elevation: 0,
            centerTitle: true,
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: enCours ? null : _enregistrer,
                  icon: enCours
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: const Text('Enregistrer', style: TextStyle(fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
          body: Form(
            key: _formulaire,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
              children: [
                TextFormField(
                  controller: _nom,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.black87),
                  decoration: _decoration('Nom du syndic *', icone: Icons.apartment),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Le nom du syndic est obligatoire.' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _telephone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
                  style: const TextStyle(color: Colors.black87),
                  decoration: _decoration(
                    'Numéro WhatsApp *',
                    indice: '212612345678',
                    aide: 'Format international, sans le 0 du début (ex. 212612345678).',
                    icone: Icons.phone_outlined,
                  ),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return 'Le téléphone est obligatoire.';
                    if (!telephoneSyndicValide(v!)) {
                      return 'Numéro international de 10 à 15 chiffres, sans 0 au début '
                          '(ex. 212612345678).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: SwitchListTile(
                    value: _actif,
                    activeThumbColor: AppColors.primaryColor,
                    onChanged: (v) => setState(() => _actif = v),
                    title: const Text('Actif',
                        style: TextStyle(fontSize: 14.5, color: Colors.black87)),
                    subtitle: Text(
                      _actif
                          ? 'Reçoit le contrat de chaque nouvelle réservation, '
                              'prolongation ou raccourcissement.'
                          : "Ne reçoit plus aucun contrat.",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 5,
                  style: const TextStyle(color: Colors.black87),
                  decoration: _decoration('Notes', icone: Icons.sticky_note_2_outlined),
                ),
                const SizedBox(height: 20),
                ..._sectionBiens(state),
                if (_erreurServeur != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_erreurServeur!,
                              style: TextStyle(fontSize: 13, color: Colors.red.shade800)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _sectionBiens(SyndicFormState state) {
    final entete = Row(
      children: [
        Icon(Icons.home_work_outlined, size: 19, color: AppColors.primaryColor),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Biens du syndic',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF17262E))),
        ),
        if (_choisis.isNotEmpty)
          EtiquetteSyndic(
            texte: '${_choisis.length} choisi${_choisis.length > 1 ? 's' : ''}',
            couleur: AppColors.primaryColor,
          ),
      ],
    );

    if (state.biens == null) {
      return [
        entete,
        const SizedBox(height: 12),
        if (state.biensStatus == AppStatus.error)
          Column(
            children: [
              Text(state.error ?? "Les biens n'ont pas pu être chargés.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.red.shade700)),
              TextButton.icon(
                onPressed: () => context.read<SyndicFormCubit>().chargerBiens(),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          )
        else
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
      ];
    }

    final biens = state.biens!;
    final q = _texte.trim().toLowerCase();
    final filtres = q.isEmpty
        ? biens
        : biens
            .where((b) =>
                b.titre.toLowerCase().contains(q) ||
                (b.syndic ?? '').toLowerCase().contains(q) ||
                b.syndics.any((s) => s.nom.toLowerCase().contains(q)))
            .toList();

    return [
      entete,
      const SizedBox(height: 4),
      Text(
        "Le syndic reçoit le contrat à chaque nouvelle réservation, prolongation ou "
        "raccourcissement dans ses biens. Un bien peut avoir plusieurs syndics : "
        "le cocher ici ne le retire pas de ses autres syndics.",
        style: TextStyle(fontSize: 12.5, height: 1.35, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 10),
      if (biens.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text("L'agence n'a encore aucun bien.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        )
      else ...[
        TextField(
          controller: _recherche,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Rechercher un bien…',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
            suffixIcon: _texte.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade500),
                    onPressed: () => _recherche.clear(),
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: filtres.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Aucun bien ne correspond à « ${_texte.trim()} ».',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                )
              : Column(
                  children: [
                    for (var i = 0; i < filtres.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
                      _ligneBien(filtres[i]),
                    ],
                  ],
                ),
        ),
      ],
    ];
  }

  Widget _ligneBien(BienDuSyndic b) {
    final coche = _choisis.contains(b.id);
    final autres = _autresSyndics(b);
    return CheckboxListTile(
      value: coche,
      dense: true,
      activeColor: AppColors.primaryColor,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (v) => setState(() {
        if (v == true) {
          _choisis.add(b.id);
        } else {
          _choisis.remove(b.id);
        }
      }),
      title: Text(b.titre, style: const TextStyle(fontSize: 14, color: Colors.black87)),
      subtitle: autres.isNotEmpty
          ? Text(
              'Aussi chez : ${autres.join(', ')}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          : null,
    );
  }
}
