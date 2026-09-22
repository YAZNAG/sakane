import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/bandeau_synchro.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/campagnes/commun/campagne_ui.dart';
import 'package:immobilier/features/campagnes/liste/cubit/campagnes_cubit.dart';
import 'package:immobilier/features/campagnes/numero/cubit/numero_campagnes_cubit.dart';
import 'package:immobilier/features/campagnes/numero/ui/numero_campagnes.dart';
import 'package:immobilier/models/campagne.dart';
import 'package:immobilier/routes.dart';
import 'package:toastification/toastification.dart';

/// Historique des campagnes de diffusion, avec leur avancement.
class CampagnesPage extends StatefulWidget {
  const CampagnesPage({super.key});

  static Widget page() => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => CampagnesCubit()..charger()),
          // Numero d'envoi des campagnes : reglage reserve aux admins.
          BlocProvider(create: (_) {
            final cubit = NumeroCampagnesCubit();
            if (numeroCampagnesAutorise()) cubit.charger();
            return cubit;
          }),
        ],
        child: const CampagnesPage(),
      );

  @override
  State<CampagnesPage> createState() => _CampagnesPageState();
}

class _CampagnesPageState extends State<CampagnesPage>
    with WidgetsBindingObserver {
  static const _intervalle = Duration(seconds: 15);

  Timer? _minuteur;

  /// Faux quand un autre ecran est ouvert par-dessus la liste.
  bool _auPremierPlan = true;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Le minuteur tourne en continu mais n'interroge le serveur que si
    // la liste est visible et qu'une campagne avance.
    _minuteur = Timer.periodic(_intervalle, (_) => _suivre());
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    final active = etat == AppLifecycleState.resumed;
    if (active && !_appActive) {
      _appActive = true;
      _suivre();
    } else if (!active) {
      _appActive = false;
    }
  }

  void _suivre() {
    if (!mounted || !_auPremierPlan || !_appActive) return;
    final cubit = context.read<CampagnesCubit>();
    if (cubit.state.aSuivre) cubit.rafraichir();
  }

  Future<void> _ouvrir(String route) async {
    final cubit = context.read<CampagnesCubit>();
    _auPremierPlan = false;
    await GoRouter.of(context).push(route);
    _auPremierPlan = true;
    if (mounted) cubit.rafraichir();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CampagneUi.fond,
      appBar: AppBar(
        title: const Text('Historique des campagnes'),
        centerTitle: true,
        actions: [
          if (numeroCampagnesAutorise())
            IconButton(
              tooltip: "Numéro WhatsApp des campagnes",
              icon: const Icon(Icons.phone_android_rounded),
              onPressed: () => ouvrirNumeroCampagnes(context),
            ),
        ],
      ),
      body: BlocConsumer<CampagnesCubit, CampagnesState>(
        listener: (context, state) {
          if (state.actionStatus == AppStatus.success) {
            showToast(state.message ?? "Opération effectuée", context,
                second: 2);
          } else if (state.actionStatus == AppStatus.error) {
            showToast("", context,
                description: state.error ?? "Erreur",
                type: ToastificationType.error,
                second: 4);
          }
        },
        builder: (context, state) => _contenu(context, state),
      ),
      floatingActionButton: !creationCampagneAutorisee() ? null : FloatingActionButton.extended(
        onPressed: () => _ouvrir(Routes.addCampagne),
        backgroundColor: AppColors.primaryColor,
        icon: const Icon(Icons.campaign_rounded, color: Colors.white),
        label: const Text('Nouvelle campagne',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _contenu(BuildContext context, CampagnesState state) {
    if (state.fetchStatus == AppStatus.loading && state.campagnes == null) {
      return Center(child: MyLoadingIndicator());
    }
    if (state.fetchStatus == AppStatus.error && state.campagnes == null) {
      return MyErrorWidget(
        error: state.error ?? "Erreur",
        action: AppStrings.tryAgain,
        actionCLick: () => context.read<CampagnesCubit>().charger(),
      );
    }

    final cubit = context.read<CampagnesCubit>();
    final toutes = state.campagnes ?? [];
    final visibles = state.campagnesFiltrees;

    return Column(
      children: [
        const BandeauSynchro(),
        _pastilleNumero(context),
        if (toutes.isNotEmpty) _filtres(context, state),
        if (state.aSuivre) _suiviAuto(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: cubit.rafraichir,
            child: toutes.isEmpty
                ? _vide(
                    Icons.campaign_outlined,
                    "Aucune campagne pour le moment",
                    "Créez une campagne pour envoyer une offre ou une "
                        "information à vos clients par WhatsApp.",
                  )
                : visibles.isEmpty
                    ? _vide(Icons.filter_alt_off_outlined,
                        "Aucune campagne dans ce filtre", null)
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 96),
                        itemCount: visibles.length,
                        itemBuilder: (context, i) =>
                            _carte(context, state, visibles[i]),
                      ),
          ),
        ),
      ],
    );
  }

  /// Numero qui envoie les campagnes (dedie ou principal), pour les admins.
  Widget _pastilleNumero(BuildContext context) {
    if (!numeroCampagnesAutorise()) return const SizedBox.shrink();
    return BlocBuilder<NumeroCampagnesCubit, NumeroCampagnesState>(
      builder: (context, etat) {
        final numero = etat.numero;
        if (numero == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: NumeroCampagnesChip(
            numero: numero,
            onTap: () => ouvrirNumeroCampagnes(context),
          ),
        );
      },
    );
  }

  Widget _filtres(BuildContext context, CampagnesState state) {
    const libelles = {
      FiltreCampagnes.toutes: 'Toutes',
      FiltreCampagnes.enCours: 'En cours',
      FiltreCampagnes.enPause: 'En pause',
      FiltreCampagnes.terminees: 'Terminées',
      FiltreCampagnes.brouillons: 'Brouillons',
    };
    final primaire = AppColors.primaryColor;

    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        children: libelles.entries.map((e) {
          final choisi = state.filtre == e.key;
          final n = state.nombre(e.key);
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(
                  e.key == FiltreCampagnes.toutes ? e.value : "${e.value} · $n"),
              selected: choisi,
              showCheckmark: false,
              onSelected: (_) =>
                  context.read<CampagnesCubit>().filtrer(e.key),
              backgroundColor: Colors.white,
              selectedColor: primaire.withValues(alpha: .14),
              side: BorderSide(
                  color: choisi ? primaire : CampagneUi.bordure),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: choisi ? FontWeight.bold : FontWeight.w500,
                color: choisi ? primaire : CampagneUi.texte,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _suiviAuto() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Row(
        children: [
          PointPulsant(couleur: CampagneUi.vert, taille: 6),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              "Mise à jour automatique pendant l'envoi",
              style: TextStyle(fontSize: 12, color: CampagneUi.gris),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vide(IconData icone, String titre, String? texte) {
    // Dans un ListView pour que le geste de rafraichissement reste possible.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 28),
      children: [
        Icon(icone, size: 60, color: CampagneUi.grisClair),
        const SizedBox(height: 14),
        Text(titre,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: CampagneUi.texte)),
        if (texte != null) ...[
          const SizedBox(height: 6),
          Text(texte,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, height: 1.4, color: CampagneUi.gris)),
        ],
      ],
    );
  }

  Widget _carte(BuildContext context, CampagnesState state, Campagne c) {
    final couleur = CampagneUi.couleurStatut(c.statut);
    final occupe = state.actionId == c.id;

    final sousTitre = [
      if (c.creeLe != null) CampagneUi.dateHeure(c.creeLe!),
      if (c.auteur != null && c.auteur!.trim().isNotEmpty) "par ${c.auteur}",
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CampagneUi.carte(
          couleurBord: c.estLancee ? couleur.withValues(alpha: .45) : null),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: c.id == null
              ? null
              : () => _ouvrir(
                  Routes.campagneDetail.replaceAll(':id', '${c.id}')),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.titre ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: CampagneUi.texte),
                          ),
                          if (sousTitre.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(sousTitre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: CampagneUi.gris)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatutCampagneChip(
                        statut: c.statut, libelle: c.statutLisible),
                    if (c.peutEtreSupprimee && suppressionCampagneAutorisee())
                      _menu(context, c, occupe)
                    else
                      const SizedBox(width: 6),
                  ],
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.nbDestinataires > 0) ...[
                        const SizedBox(height: 12),
                        BarreCampagne(valeur: c.avancement, couleur: couleur),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _compteurs(c)),
                            Text("${c.pourcentage} %",
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: couleur)),
                          ],
                        ),
                      ],
                      ..._infoEtat(c),
                      if ((c.estLancee || c.estEnPause) && gestionCampagneAutorisee()) ...[
                        const SizedBox(height: 12),
                        _actionRapide(context, c, occupe),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compteurs(Campagne c) {
    final morceaux = <TextSpan>[
      TextSpan(
        text: CampagneUi.pluriel(c.nbEnvoyes, "envoyé"),
        style: const TextStyle(color: CampagneUi.vert),
      ),
      if (c.nbEchecs > 0)
        TextSpan(
          text: " · ${CampagneUi.pluriel(c.nbEchecs, 'échec')}",
          style: const TextStyle(color: CampagneUi.rouge),
        ),
      if (c.nbEnAttente > 0)
        TextSpan(text: " · ${c.nbEnAttente} en attente"),
      if (c.nbIgnores > 0)
        TextSpan(text: " · ${CampagneUi.pluriel(c.nbIgnores, 'ignoré')}"),
    ];
    return Text.rich(
      TextSpan(children: morceaux),
      style: const TextStyle(
          fontSize: 12.5, fontWeight: FontWeight.w600, color: CampagneUi.gris),
    );
  }

  List<Widget> _infoEtat(Campagne c) {
    Widget ligne(IconData icone, String texte, Color couleur) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(icone, size: 15, color: couleur),
              const SizedBox(width: 6),
              Expanded(
                child: Text(texte,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: couleur)),
              ),
            ],
          ),
        );

    if (c.estLancee) {
      return [
        ligne(
          Icons.timer_outlined,
          "≈ ${CampagneUi.duree(c.minutesEstimees)} restantes · "
          "${c.parMinute} messages/min",
          CampagneUi.vert,
        ),
      ];
    }
    if (c.estEnPause) {
      return [
        ligne(
          Icons.pause_circle_outline,
          c.pauseeA != null
              ? "En pause depuis ${_minuscule(CampagneUi.dateHeure(c.pauseeA!))}"
                  " · ${c.nbEnAttente} en attente"
              : "Envoi suspendu",
          CampagneUi.orange,
        ),
      ];
    }
    if (c.estProgrammee && c.planifieeA != null) {
      return [
        ligne(Icons.event_available_outlined,
            "Envoi prévu ${_minuscule(CampagneUi.dateHeure(c.planifieeA!))}",
            CampagneUi.bleu),
      ];
    }
    return const [];
  }

  String _minuscule(String texte) =>
      texte.startsWith(RegExp(r'[0-9]')) ? "le $texte" : texte.toLowerCase();

  Widget _actionRapide(BuildContext context, Campagne c, bool occupe) {
    final pause = c.estLancee;
    final couleur = pause ? CampagneUi.orange : CampagneUi.vert;

    final icone = occupe
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: pause ? couleur : Colors.white))
        : Icon(pause ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 20);
    final libelle = Text(pause ? "Mettre en pause" : "Reprendre l'envoi",
        style: const TextStyle(fontWeight: FontWeight.bold));
    final onPressed = occupe || c.id == null
        ? null
        : () => pause ? _confirmerPause(context, c) : _confirmerReprise(context, c);

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: pause
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: icone,
              label: libelle,
              style: OutlinedButton.styleFrom(
                foregroundColor: couleur,
                side: BorderSide(color: couleur.withValues(alpha: .6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: icone,
              label: libelle,
              style: ElevatedButton.styleFrom(
                backgroundColor: couleur,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
    );
  }

  Widget _menu(BuildContext context, Campagne c, bool occupe) {
    return PopupMenuButton<String>(
      enabled: !occupe,
      icon: const Icon(Icons.more_vert, color: CampagneUi.grisClair),
      padding: EdgeInsets.zero,
      tooltip: "Plus d'actions",
      onSelected: (_) => _confirmerSuppression(context, c),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'supprimer',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: CampagneUi.rouge, size: 20),
              SizedBox(width: 10),
              Text("Supprimer"),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmerPause(BuildContext context, Campagne c) async {
    final cubit = context.read<CampagnesCubit>();
    final ok = await confirmerCampagne(
      context,
      titre: "Mettre en pause ?",
      message: "Aucun nouveau message ne partira. Les messages restants "
          "restent en attente, dans le même ordre.",
      confirmer: "Mettre en pause",
      icone: Icons.pause_rounded,
      couleur: CampagneUi.orange,
    );
    if (ok) cubit.pause(c.id!);
  }

  void _confirmerReprise(BuildContext context, Campagne c) async {
    final cubit = context.read<CampagnesCubit>();
    final ok = await confirmerCampagne(
      context,
      titre: "Reprendre l'envoi ?",
      message: "L'envoi reprendra au message #${c.prochainOrdre}, au rythme "
          "de ${c.parMinute} messages par minute.",
      confirmer: "Reprendre",
      icone: Icons.play_arrow_rounded,
      couleur: CampagneUi.vert,
    );
    if (ok) cubit.reprendre(c.id!);
  }

  void _confirmerSuppression(BuildContext context, Campagne c) async {
    final cubit = context.read<CampagnesCubit>();
    final ok = await confirmerCampagne(
      context,
      titre: "Supprimer la campagne ?",
      message: "« ${c.titre} » et son historique d'envoi seront "
          "définitivement supprimés.",
      confirmer: "Supprimer",
      icone: Icons.delete_outline,
      couleur: CampagneUi.rouge,
    );
    if (ok && c.id != null) cubit.supprimer(c.id!);
  }
}
