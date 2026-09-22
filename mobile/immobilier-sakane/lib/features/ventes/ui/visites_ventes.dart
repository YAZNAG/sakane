import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/features/ventes/ui/components/visite_outils.dart';
import 'package:immobilier/features/ventes/ui/dossier_vente.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/repository/repository.dart';

/// Les visites recentes, tous biens confondus ; une visite ouvre le dossier du bien.
class VisitesVentesPage extends StatefulWidget {
  const VisitesVentesPage({super.key});

  @override
  State<VisitesVentesPage> createState() => _VisitesVentesPageState();
}

class _VisitesVentesPageState extends State<VisitesVentesPage> {
  TableauVentes? _tableau;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _erreur = null);
    try {
      final t = await Dependencies.get<Repository>().fetchTableauVentes();
      if (mounted) setState(() => _tableau = t);
    } catch (ex) {
      if (mounted) setState(() => _erreur = messageErreurBail(ex));
    }
  }

  Future<void> _ouvrir(VisiteVente v) async {
    final id = v.bienId ?? v.bien?.id;
    if (id == null) return;
    await GoRouter.of(context).push(cheminDossierVente(id, onglet: 'visites'));
    if (mounted) _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CouleursBail.fond,
      appBar: AppBar(
        title: const Text('Visites', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: CouleursVente.teinte,
      ),
      body: _corps(),
    );
  }

  Widget _corps() {
    final t = _tableau;
    if (t == null) {
      if (_erreur != null) {
        return Center(
          child: SingleChildScrollView(
            child: MyErrorWidget(error: _erreur!, action: AppStrings.tryAgain, actionCLick: _charger),
          ),
        );
      }
      return Center(child: MyLoadingIndicator());
    }
    final visites = [...t.visitesRecentes]
      ..sort((a, b) => (b.dateVisite ?? DateTime(0)).compareTo(a.dateVisite ?? DateTime(0)));
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
        children: [
          TitreSection(
            texte: 'Visites récentes',
            icone: Icons.directions_walk,
            couleur: CouleursVente.teinte,
            compteur: '${pluriel(t.visitesCeMois, 'visite')} ce mois',
          ),
          if (visites.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text('Aucune visite récente.',
                  textAlign: TextAlign.center, style: TextStyle(color: CouleursBail.texteDoux, fontSize: 14)),
            ),
          for (final v in visites) ...[_carte(v), const SizedBox(height: 8)],
        ],
      ),
    );
  }

  Widget _carte(VisiteVente v) {
    final contenu = Row(
      children: [
        BlocDateVisite(date: v.dateVisite),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.visiteurNom.isEmpty ? 'Visiteur' : v.visiteurNom,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: CouleursBail.texte)),
              if (v.bien != null)
                Text(v.bien!.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  PastilleSignatureVisite(visite: v),
                  if ((v.agent ?? '').isNotEmpty)
                    PastilleBail(texte: v.agent!, couleur: CouleursBail.texteDoux, icone: Icons.badge_outlined),
                ],
              ),
            ],
          ),
        ),
        BoutonsContact(tel: v.visiteurTel),
      ],
    );
    if (!peutSignerVisite || v.signe) return CarteBail(onTap: () => _ouvrir(v), child: contenu);
    return CarteBail(
      onTap: () => _ouvrir(v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          contenu,
          const SizedBox(height: 10),
          BoutonSignerVisite(onPressed: () => _signer(v)),
        ],
      ),
    );
  }

  Future<void> _signer(VisiteVente v) async {
    final signee = await faireSignerVisite(context, v);
    if (signee != null && mounted) _charger();
  }
}
