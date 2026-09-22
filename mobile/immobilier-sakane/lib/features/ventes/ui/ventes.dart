import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/ventes/cubit/ventes_cubit.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/models/vente.dart';

/// Vente de biens : la liste, filtree par statut, avec recherche.
class VentesPage extends StatefulWidget {
  const VentesPage({super.key});

  static Widget page({String? filtre, String? dossier}) => BlocProvider(
        create: (_) => VentesCubit(
          filtre: VentesCubit.filtres.containsKey(filtre) ? filtre! : 'tous',
          dossier: dossier,
        )..charger(),
        child: const VentesPage(),
      );

  @override
  State<VentesPage> createState() => _VentesPageState();
}

class _VentesPageState extends State<VentesPage> {
  final TextEditingController _recherche = TextEditingController();
  Timer? _attente;

  VentesCubit get _cubit => context.read<VentesCubit>();

  @override
  void dispose() {
    _attente?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  void _surRecherche(String texte) {
    setState(() {});
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _cubit.rechercher(texte);
    });
  }

  Future<void> _ouvrir(BienVente b) async {
    final cubit = _cubit;
    await GoRouter.of(context).push(cheminDossierVente(b.id));
    cubit.charger(silencieux: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CouleursBail.fond,
      appBar: AppBar(
        title: const Text('Vente de biens', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: CouleursVente.teinte,
      ),
      body: BlocBuilder<VentesCubit, VentesState>(
        builder: (context, state) => Column(
          children: [
            _entete(state),
            if (state.statut == AppStatus.loading && state.biens != null)
              const LinearProgressIndicator(minHeight: 2, color: CouleursVente.teinte),
            Expanded(child: _liste(state)),
          ],
        ),
      ),
    );
  }

  Widget _entete(VentesState state) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        children: [
          TextField(
            controller: _recherche,
            onChanged: _surRecherche,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Bien, adresse, propriétaire…',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
              suffixIcon: _recherche.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade500),
                      onPressed: () {
                        _recherche.clear();
                        _surRecherche('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in VentesCubit.filtres.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.value),
                      selected: state.filtre == f.key,
                      onSelected: (_) => _cubit.changerFiltre(f.key),
                      selectedColor: _couleurFiltre(f.key).withValues(alpha: .15),
                      labelStyle: TextStyle(
                        fontWeight: state.filtre == f.key ? FontWeight.w700 : FontWeight.w500,
                        color: state.filtre == f.key ? _couleurFiltre(f.key) : CouleursBail.texte,
                      ),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: CouleursBail.bordure),
                      showCheckmark: false,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _couleurFiltre(String filtre) {
    switch (filtre) {
      case 'a_vendre':
        return CouleursVente.aVendre;
      case 'compromis':
        return CouleursVente.compromis;
      case 'vendu':
        return CouleursVente.vendu;
      case 'sans_mandat':
        return CouleursVente.sansMandat;
      default:
        return CouleursVente.teinte;
    }
  }

  Widget _liste(VentesState state) {
    final biens = state.biens;
    if (biens == null) {
      if (state.statut == AppStatus.error) {
        return Center(
          child: SingleChildScrollView(
            child: MyErrorWidget(
              error: state.erreur ?? 'Erreur',
              action: AppStrings.tryAgain,
              actionCLick: () => _cubit.charger(),
            ),
          ),
        );
      }
      return Center(child: MyLoadingIndicator());
    }
    return RefreshIndicator(
      onRefresh: () => _cubit.charger(silencieux: true),
      child: biens.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(28, 60, 28, 40),
              children: [
                const Icon(Icons.sell_outlined, size: 56, color: CouleursBail.texteDoux),
                const SizedBox(height: 12),
                Text(
                  state.recherche.trim().isNotEmpty
                      ? 'Aucun bien ne correspond à la recherche.'
                      : 'Aucun bien dans cette vue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CouleursBail.texteDoux, fontSize: 14),
                ),
                if (state.statut == AppStatus.error)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(state.erreur ?? '',
                        textAlign: TextAlign.center, style: const TextStyle(color: CouleursBail.retard)),
                  ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
              itemCount: biens.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => CarteBienVente(bien: biens[i], onTap: () => _ouvrir(biens[i])),
            ),
    );
  }
}

/// Carte d'un bien en vente : photo, titre, adresse, prix, statut, mandat, visites.
class CarteBienVente extends StatelessWidget {
  final BienVente bien;
  final VoidCallback? onTap;

  /// Actions rapides sous la carte (dossiers).
  final Widget? pied;

  const CarteBienVente({super.key, required this.bien, this.onTap, this.pied});

  @override
  Widget build(BuildContext context) {
    final b = bien;
    final contenu = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhotoBien(url: b.photo, taille: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: CouleursBail.texte)),
                if ((b.adresse ?? '').isNotEmpty)
                  Text(b.adresse!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
                const SizedBox(height: 4),
                Text(
                  '${prixVente(b.prix)}${(b.surface ?? 0) > 0 ? ' • ${prixSimple(b.surface!)} m²' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: CouleursVente.teinte),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    PastilleStatutVente(statut: b.statutVente, libelle: b.statutVenteLibelle),
                    PastilleMandat(mandat: b.mandat),
                    PastilleBail(
                      texte: b.nbVisites == 0 ? 'Aucune visite' : pluriel(b.nbVisites, 'visite'),
                      couleur: CouleursBail.texteDoux,
                      icone: Icons.directions_walk,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: CouleursBail.texteDoux),
        ],
      );
    return CarteBail(
      onTap: onTap,
      child: pied == null
          ? contenu
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [contenu, const Divider(height: 18), pied!],
            ),
    );
  }
}
