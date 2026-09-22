import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/campagnes/commun/campagne_ui.dart';
import 'package:immobilier/features/campagnes/detail/cubit/detail_campagne_cubit.dart';
import 'package:immobilier/models/campagne.dart';
import 'package:toastification/toastification.dart';

/// Suivi d'une campagne : avancement, actions et destinataires dans
/// l'ordre d'envoi.
class DetailCampagnePage extends StatefulWidget {
  const DetailCampagnePage({super.key});

  static Widget page({required int id}) => BlocProvider(
        create: (_) => DetailCampagneCubit(id)..charger(),
        child: const DetailCampagnePage(),
      );

  @override
  State<DetailCampagnePage> createState() => _DetailCampagnePageState();
}

class _DetailCampagnePageState extends State<DetailCampagnePage>
    with WidgetsBindingObserver {
  final _recherche = TextEditingController();

  /// Statut de destinataire retenu par les tuiles, null = tous.
  String? _filtre;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recherche.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    final cubit = context.read<DetailCampagneCubit>();
    if (etat == AppLifecycleState.resumed) {
      cubit.reprendreSuivi();
    } else if (etat == AppLifecycleState.paused ||
        etat == AppLifecycleState.hidden) {
      cubit.suspendreSuivi();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CampagneUi.fond,
      appBar: AppBar(
        title: const Text('Suivi de la campagne'),
        centerTitle: true,
      ),
      body: BlocConsumer<DetailCampagneCubit, DetailCampagneState>(
        listener: (context, state) {
          if (state.actionStatus == AppStatus.success) {
            showToast(state.message ?? "Opération effectuée", context,
                second: 3);
            if (state.supprimee) GoRouter.of(context).pop(true);
          } else if (state.actionStatus == AppStatus.error) {
            showToast("", context,
                description: state.error ?? "Erreur",
                type: ToastificationType.error,
                second: 4);
          }
        },
        builder: (context, state) {
          if (state.campagne == null) {
            if (state.fetchStatus == AppStatus.error) {
              return MyErrorWidget(
                error: state.error ?? "Erreur",
                action: AppStrings.tryAgain,
                actionCLick: () =>
                    context.read<DetailCampagneCubit>().charger(),
              );
            }
            return Center(child: MyLoadingIndicator());
          }
          return _contenu(context, state, state.campagne!);
        },
      ),
    );
  }

  Widget _contenu(
      BuildContext context, DetailCampagneState state, Campagne c) {
    final cubit = context.read<DetailCampagneCubit>();
    final destinataires = _destinatairesFiltres(c);
    final prochain = c.estLancee ? c.prochainOrdre : null;

    return RefreshIndicator(
      onRefresh: cubit.rafraichir,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _enTete(c),
                const SizedBox(height: 12),
                _avancement(c),
                const SizedBox(height: 12),
                _tuiles(c),
                const SizedBox(height: 14),
                _actions(context, state, c),
                const SizedBox(height: 14),
                _apercuMessage(c),
                const SizedBox(height: 20),
                _enTeteDestinataires(c, destinataires.length),
                const SizedBox(height: 10),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
            sliver: destinataires.isEmpty
                ? SliverToBoxAdapter(child: _aucunDestinataire(c))
                : SliverList.builder(
                    itemCount: destinataires.length,
                    itemBuilder: (_, i) =>
                        _ligneDestinataire(destinataires[i], prochain),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // En-tete et avancement
  // ---------------------------------------------------------------

  Widget _enTete(Campagne c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CampagneUi.carte(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(c.titre ?? '',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: CampagneUi.texte)),
              ),
              const SizedBox(width: 10),
              StatutCampagneChip(
                  statut: c.statut, libelle: c.statutLisible, grand: true),
            ],
          ),
          const SizedBox(height: 10),
          if (c.creeLe != null || c.auteur != null)
            _ligne(
              Icons.person_outline,
              [
                if (c.creeLe != null) "Créée ${_le(c.creeLe!)}",
                if (c.auteur != null) "par ${c.auteur}",
              ].join(' '),
            ),
          if (c.planifieeA != null && c.estProgrammee)
            _ligne(Icons.event_available_outlined,
                "Envoi prévu ${_le(c.planifieeA!)}",
                couleur: CampagneUi.bleu),
          if (c.demarreeA != null)
            _ligne(Icons.play_circle_outline, "Démarrée ${_le(c.demarreeA!)}"),
          if (c.estEnPause && c.pauseeA != null)
            _ligne(Icons.pause_circle_outline,
                "En pause depuis ${_le(c.pauseeA!)}",
                couleur: CampagneUi.orange),
          if (c.repriseA != null && !c.estEnPause)
            _ligne(Icons.replay_rounded, "Reprise ${_le(c.repriseA!)}"),
          if (c.termineeA != null)
            _ligne(Icons.done_all_rounded, "Terminée ${_le(c.termineeA!)}"),
        ],
      ),
    );
  }

  Widget _avancement(Campagne c) {
    final couleur = CampagneUi.couleurStatut(c.statut);
    final traites = c.nbDestinataires - c.nbEnAttente;
    final attente = c.estLancee || c.estEnPause || c.estProgrammee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CampagneUi.carte(
          couleurBord: c.estLancee ? couleur.withValues(alpha: .45) : null),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: c.avancement),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          backgroundColor: const Color(0xFFE9EEF1),
                          valueColor: AlwaysStoppedAnimation<Color>(couleur),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${c.pourcentage} %",
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: couleur)),
                        const Text("traités",
                            style: TextStyle(
                                fontSize: 11, color: CampagneUi.gris)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$traites / ${CampagneUi.pluriel(c.nbDestinataires, 'destinataire')}",
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: CampagneUi.texte),
                    ),
                    const SizedBox(height: 8),
                    _info(Icons.speed_rounded,
                        "${c.parMinute} messages par minute, dans l'ordre de la liste"),
                    if (c.dernierEnvoiA != null)
                      _info(Icons.history_rounded,
                          "Dernier envoi ${CampagneUi.depuis(c.dernierEnvoiA!)}"),
                    if (attente && c.nbEnAttente > 0)
                      _info(
                        Icons.timer_outlined,
                        c.estEnPause
                            ? "≈ ${CampagneUi.duree(c.minutesEstimees)} d'envoi restant après reprise"
                            : "≈ ${CampagneUi.duree(c.minutesEstimees)} restantes",
                        couleur: c.estLancee ? CampagneUi.vert : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (c.estActive) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const PointPulsant(couleur: CampagneUi.vert, taille: 6),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    c.estLancee
                        ? "Envoi automatique en cours · mise à jour toutes les 10 s"
                        : "L'envoi démarrera tout seul à l'heure prévue",
                    style: const TextStyle(
                        fontSize: 12, color: CampagneUi.gris),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tuiles(Campagne c) {
    Widget tuile(String statut, String libelle, int valeur, IconData icone,
        Color couleur) {
      final choisi = _filtre == statut;
      return Expanded(
        child: Material(
          color: choisi ? couleur.withValues(alpha: .1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _filtre = choisi ? null : statut),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: choisi ? couleur : CampagneUi.bordure,
                    width: choisi ? 1.6 : 1),
              ),
              child: Column(
                children: [
                  Icon(icone, size: 20, color: couleur),
                  const SizedBox(height: 4),
                  Text("$valeur",
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: couleur)),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(libelle,
                        maxLines: 1,
                        style: const TextStyle(
                            fontSize: 11.5, color: CampagneUi.gris)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tuile('envoye', "Envoyés", c.nbEnvoyes, Icons.check_circle_rounded,
            CampagneUi.vert),
        const SizedBox(width: 8),
        tuile('echec', "Échecs", c.nbEchecs, Icons.cancel_rounded,
            CampagneUi.rouge),
        const SizedBox(width: 8),
        tuile('en_attente', "En attente", c.nbEnAttente,
            Icons.hourglass_top_rounded, CampagneUi.ardoise),
        const SizedBox(width: 8),
        tuile('ignore', "Ignorés", c.nbIgnores, Icons.block_rounded,
            CampagneUi.grisClair),
      ],
    );
  }

  // ---------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------

  Widget _actions(
      BuildContext context, DetailCampagneState state, Campagne c) {
    final cubit = context.read<DetailCampagneCubit>();
    final action = state.action;
    final occupe = action != null;

    Widget attente(Color couleur) => SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: couleur),
        );

    final gerer = gestionCampagneAutorisee();
    Widget? principal;
    if (!gerer) {
      principal = null;
    } else if (c.estBrouillon || c.estProgrammee) {
      principal = _boutonPrincipal(
        libelle: "Lancer l'envoi",
        icone: action == 'lancer'
            ? attente(Colors.white)
            : const Icon(Icons.send_rounded),
        couleur: AppColors.primaryColor,
        onPressed: occupe ? null : () => _confirmerLancement(context, c),
      );
    } else if (c.estLancee) {
      principal = _boutonPrincipal(
        libelle: "Mettre en pause",
        icone: action == 'pause'
            ? attente(Colors.white)
            : const Icon(Icons.pause_rounded),
        couleur: CampagneUi.orange,
        onPressed: occupe
            ? null
            : () async {
                final ok = await confirmerCampagne(
                  context,
                  titre: "Mettre en pause ?",
                  message: "Aucun nouveau message ne partira. Les messages "
                      "restants restent en attente, dans le même ordre.",
                  confirmer: "Mettre en pause",
                  icone: Icons.pause_rounded,
                  couleur: CampagneUi.orange,
                );
                if (ok) cubit.pause();
              },
      );
    } else if (c.estEnPause) {
      principal = _boutonPrincipal(
        libelle: "Reprendre",
        icone: action == 'reprendre'
            ? attente(Colors.white)
            : const Icon(Icons.play_arrow_rounded),
        couleur: CampagneUi.vert,
        onPressed: occupe
            ? null
            : () async {
                final ok = await confirmerCampagne(
                  context,
                  titre: "Reprendre l'envoi ?",
                  message: "L'envoi reprendra au message #${c.prochainOrdre}, "
                      "au rythme de ${c.parMinute} messages par minute.",
                  confirmer: "Reprendre",
                  icone: Icons.play_arrow_rounded,
                  couleur: CampagneUi.vert,
                );
                if (ok) cubit.reprendre();
              },
      );
    }

    final secondaires = <Widget>[
      if (gerer && c.nbEchecs > 0 && !c.estLancee)
        _boutonSecondaire(
          libelle: "Relancer les échecs (${c.nbEchecs})",
          icone: action == 'relancer'
              ? attente(CampagneUi.texte)
              : const Icon(Icons.refresh_rounded, size: 19),
          onPressed: occupe
              ? null
              : () async {
                  final ok = await confirmerCampagne(
                    context,
                    titre: "Relancer les échecs ?",
                    message: "Les ${CampagneUi.pluriel(c.nbEchecs, 'message')} "
                        "en échec seront remis en file et renvoyés au rythme "
                        "de ${c.parMinute} messages par minute.",
                    confirmer: "Relancer",
                    icone: Icons.refresh_rounded,
                  );
                  if (ok) cubit.relancerEchecs();
                },
        ),
      if (creationCampagneAutorisee())
      _boutonSecondaire(
        libelle: "Envoi test",
        icone: action == 'test'
            ? attente(CampagneUi.texte)
            : const Icon(Icons.science_outlined, size: 19),
        onPressed: occupe
            ? null
            : () async {
                final numero = await demanderNumeroTest(context);
                if (numero != null) cubit.envoyerTest(numero);
              },
      ),
      if (gerer && (c.estLancee || c.estProgrammee || c.estEnPause))
        _boutonSecondaire(
          libelle: "Annuler la campagne",
          couleur: CampagneUi.rouge,
          icone: action == 'annuler'
              ? attente(CampagneUi.rouge)
              : const Icon(Icons.stop_circle_outlined, size: 19),
          onPressed: occupe
              ? null
              : () async {
                  final restants = c.nbEnAttente;
                  final ok = await confirmerCampagne(
                    context,
                    titre: "Annuler la campagne ?",
                    message: restants > 0
                        ? "Les ${CampagneUi.pluriel(restants, 'message')} "
                            "encore en attente ne seront jamais envoyés. "
                            "Les messages déjà partis ne sont pas concernés."
                        : "La campagne sera arrêtée définitivement.",
                    confirmer: "Annuler la campagne",
                    retour: "Garder",
                    icone: Icons.stop_circle_outlined,
                    couleur: CampagneUi.rouge,
                  );
                  if (ok) cubit.annuler();
                },
        ),
      if (c.peutEtreSupprimee && suppressionCampagneAutorisee())
        _boutonSecondaire(
          libelle: "Supprimer",
          couleur: CampagneUi.rouge,
          icone: action == 'supprimer'
              ? attente(CampagneUi.rouge)
              : const Icon(Icons.delete_outline, size: 19),
          onPressed: occupe
              ? null
              : () async {
                  final ok = await confirmerCampagne(
                    context,
                    titre: "Supprimer la campagne ?",
                    message: "« ${c.titre} » et son historique d'envoi "
                        "seront définitivement supprimés.",
                    confirmer: "Supprimer",
                    icone: Icons.delete_outline,
                    couleur: CampagneUi.rouge,
                  );
                  if (ok) cubit.supprimer();
                },
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (principal != null) ...[principal, const SizedBox(height: 10)],
        Wrap(spacing: 8, runSpacing: 8, children: secondaires),
      ],
    );
  }

  Widget _boutonPrincipal({
    required String libelle,
    required Widget icone,
    required Color couleur,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icone,
        label: Text(libelle,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: couleur,
          foregroundColor: Colors.white,
          disabledBackgroundColor: couleur.withValues(alpha: .55),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _boutonSecondaire({
    required String libelle,
    required Widget icone,
    required VoidCallback? onPressed,
    Color couleur = CampagneUi.texte,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icone,
      label: Text(libelle, style: const TextStyle(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: couleur,
        backgroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: BorderSide(
            color: couleur == CampagneUi.texte
                ? CampagneUi.bordure
                : couleur.withValues(alpha: .45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _confirmerLancement(BuildContext context, Campagne c) async {
    final cubit = context.read<DetailCampagneCubit>();
    final n = c.nbDestinataires;
    final minutes = (n / (c.parMinute <= 0 ? 2 : c.parMinute)).ceil();
    final ok = await confirmerCampagne(
      context,
      titre: "Lancer l'envoi maintenant ?",
      message: n > 0
          ? "${CampagneUi.pluriel(n, 'message')} vont partir automatiquement, "
              "${c.parMinute} par minute, dans l'ordre de la liste "
              "(≈ ${CampagneUi.duree(minutes)})."
          : "Les messages partiront automatiquement, ${c.parMinute} par minute, "
              "dans l'ordre de la liste.",
      confirmer: "Lancer",
      icone: Icons.send_rounded,
      couleur: AppColors.primaryColor,
    );
    if (ok) cubit.lancer();
  }

  // ---------------------------------------------------------------
  // Message
  // ---------------------------------------------------------------

  Widget _apercuMessage(Campagne c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CampagneUi.carte(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat_outlined, size: 18, color: CampagneUi.gris),
              SizedBox(width: 8),
              Text("Message envoyé",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CampagneUi.texte)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECE5DD),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: CampagneUi.bulle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.imageUrl != null && c.imageUrl!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: c.imageUrl!,
                          height: 170,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            height: 90,
                            color: Colors.white54,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(c.message ?? '',
                          style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: CampagneUi.texte)),
                    ),
                    if (c.lien != null && c.lien!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                        child: Text(c.lien!,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF027EB5),
                                decoration: TextDecoration.underline)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Les variables comme {client_name} sont remplacées par le nom de "
            "chaque client.",
            style: TextStyle(fontSize: 11.5, color: CampagneUi.gris),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Destinataires
  // ---------------------------------------------------------------

  List<DestinataireCampagne> _destinatairesFiltres(Campagne c) {
    final requete = _recherche.text.trim().toLowerCase();
    final chiffres = requete.replaceAll(RegExp(r'[^0-9]'), '');
    return (c.destinataires ?? []).where((d) {
      if (_filtre != null && d.statut != _filtre) return false;
      if (requete.isEmpty) return true;
      if ((d.nom ?? '').toLowerCase().contains(requete)) return true;
      final tel = (d.telephone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      return chiffres.isNotEmpty && tel.contains(chiffres);
    }).toList();
  }

  Widget _enTeteDestinataires(Campagne c, int visibles) {
    final total = c.destinataires?.length ?? 0;
    const libelles = {
      'envoye': 'Envoyés',
      'echec': 'Échecs',
      'en_attente': 'En attente',
      'ignore': 'Ignorés',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "Destinataires · ordre d'envoi",
                style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: CampagneUi.texte),
              ),
            ),
            Text(
              visibles == total ? "$total" : "$visibles / $total",
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CampagneUi.gris),
            ),
          ],
        ),
        if (total > 0) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _recherche,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: "Rechercher un nom ou un numéro",
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _recherche.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(_recherche.clear),
                      icon: const Icon(Icons.close_rounded),
                    ),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: CampagneUi.bordure),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: CampagneUi.bordure),
              ),
            ),
          ),
        ],
        if (_filtre != null) ...[
          const SizedBox(height: 8),
          InputChip(
            label: Text("Filtre : ${libelles[_filtre] ?? _filtre}"),
            onDeleted: () => setState(() => _filtre = null),
            deleteIcon: const Icon(Icons.close_rounded, size: 17),
            backgroundColor: Colors.white,
            side: const BorderSide(color: CampagneUi.bordure),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
        ],
      ],
    );
  }

  Widget _aucunDestinataire(Campagne c) {
    final vide = (c.destinataires ?? []).isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(vide ? Icons.group_off_outlined : Icons.search_off_rounded,
              size: 44, color: CampagneUi.grisClair),
          const SizedBox(height: 8),
          Text(
            vide
                ? "La liste des destinataires sera établie au lancement."
                : "Aucun destinataire ne correspond.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: CampagneUi.gris),
          ),
        ],
      ),
    );
  }

  Widget _ligneDestinataire(DestinataireCampagne d, int? prochainOrdre) {
    final (icone, couleur, libelle) = switch (d.statut) {
      'envoye' => (Icons.check_rounded, CampagneUi.vert, "Envoyé"),
      'echec' => (Icons.close_rounded, CampagneUi.rouge, "Échec"),
      'ignore' => (Icons.block_rounded, CampagneUi.grisClair, "Ignoré"),
      _ => (Icons.hourglass_top_rounded, CampagneUi.ardoise, "En attente"),
    };
    // Le prochain message a partir est mis en avant pendant l'envoi.
    final prochain =
        d.enAttente && d.ordre != null && d.ordre == prochainOrdre;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: CampagneUi.carte(
          couleurBord: prochain ? CampagneUi.vert.withValues(alpha: .5) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3F5),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              d.ordre != null ? "#${d.ordre}" : "—",
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: CampagneUi.gris),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.nom ?? d.telephone ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CampagneUi.texte)),
                if (d.telephone != null && d.telephone!.isNotEmpty)
                  Text(d.telephone!,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 12.5, color: CampagneUi.gris)),
                if (d.enEchec && d.erreur != null && d.erreur!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(d.erreur!,
                        style: const TextStyle(
                            fontSize: 12, color: CampagneUi.rouge)),
                  ),
                if (d.ignore && d.erreur != null && d.erreur!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(d.erreur!,
                        style: const TextStyle(
                            fontSize: 12, color: CampagneUi.gris)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icone, size: 13, color: couleur),
                    const SizedBox(width: 3),
                    Text(prochain ? "Prochain" : libelle,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: couleur)),
                  ],
                ),
              ),
              if (d.envoyeA != null)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(_horodatage(d.envoyeA!),
                      style: const TextStyle(
                          fontSize: 11.5, color: CampagneUi.gris)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Elements communs
  // ---------------------------------------------------------------

  Widget _ligne(IconData icone, String texte, {Color? couleur}) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          children: [
            Icon(icone, size: 16, color: couleur ?? CampagneUi.gris),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texte,
                  style: TextStyle(
                      fontSize: 13, color: couleur ?? CampagneUi.gris)),
            ),
          ],
        ),
      );

  Widget _info(IconData icone, String texte, {Color? couleur}) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 15, color: couleur ?? CampagneUi.gris),
            const SizedBox(width: 6),
            Expanded(
              child: Text(texte,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      fontWeight:
                          couleur != null ? FontWeight.w600 : FontWeight.normal,
                      color: couleur ?? CampagneUi.gris)),
            ),
          ],
        ),
      );

  /// "le 12/09/2026 à 18h00", "aujourd'hui à 14h05".
  String _le(DateTime d) {
    final texte = CampagneUi.dateHeure(d);
    return texte.startsWith(RegExp(r'[0-9]')) ? "le $texte" : texte.toLowerCase();
  }

  /// Heure seule si l'envoi date d'aujourd'hui.
  String _horodatage(DateTime d) {
    final n = DateTime.now();
    if (d.year == n.year && d.month == n.month && d.day == n.day) {
      return CampagneUi.heure(d);
    }
    return "${CampagneUi.deux(d.day)}/${CampagneUi.deux(d.month)} "
        "${CampagneUi.heure(d)}";
  }
}
