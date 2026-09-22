import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/entete_defilant.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/components/statut_bien_chip.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_string.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/routes.dart';

/// Calendrier, depuis l'accueil : on choisit d'abord le bien, puis son
/// calendrier s'ouvre.
class CalendrierBiensPage extends StatefulWidget {
  const CalendrierBiensPage({super.key});

  @override
  State<CalendrierBiensPage> createState() => _CalendrierBiensPageState();
}

class _CalendrierBiensPageState extends State<CalendrierBiensPage> {
  static const _gris = Color(0xFF6B7B84);

  final _recherche = TextEditingController();
  List<Realestate>? _biens;
  String? _erreur;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _recherche.addListener(() => setState(() {}));
    _charger();
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    String? erreur;
    List<Realestate>? biens;
    try {
      biens = await Dependencies.get<Repository>().getRealestates();
      biens.sort((a, b) => (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase()));
    } on NetworkConnectivityException {
      erreur = 'Pas de connexion. Vérifiez le réseau puis réessayez.';
    } on UnAuthenticatedException {
      logout();
      return;
    } on UnAuthorizedException {
      erreur = "Vous n'avez pas accès à la liste des biens.";
    } catch (_) {
      erreur = "La liste des biens n'a pas pu être chargée.";
    }
    if (!mounted) return;
    setState(() {
      _chargement = false;
      // Au rafraichissement, la liste deja affichee reste en cas d'echec.
      if (biens != null) _biens = biens;
      _erreur = erreur;
    });
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

  List<Realestate> _filtrer(List<Realestate> tous) {
    final q = _sansAccents(_recherche.text.trim());
    if (q.isEmpty) return tous;
    return tous.where((r) {
      final texte = _sansAccents([
        r.title,
        r.address?.address,
        r.address?.city?.name,
        r.secteur?.name,
        r.dossier?.nom,
        '#${r.id}',
        '${r.id}',
      ].whereType<String>().join(' '));
      return texte.contains(q);
    }).toList();
  }

  void _ouvrir(Realestate bien) {
    if (bien.id == null) return;
    final titre = bien.title ?? '';
    GoRouter.of(context).push(Uri(
      path: Routes.calendrierBien.replaceAll(':id', bien.id.toString()),
      queryParameters: titre.isEmpty ? null : {'titre': titre},
    ).toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F7),
      appBar: AppBar(
        title: const Text('Calendrier',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (Dependencies.get<Manager>().can(AppPermission.viewAirbnb))
          IconButton(
            tooltip: 'Airbnb',
            icon: const FaIcon(FontAwesomeIcons.airbnb, color: Colors.white, size: 20),
            onPressed: () => GoRouter.of(context).push(Routes.airbnbBiens),
          ),
        ],
      ),
      body: _corps(),
      floatingActionButton: Dependencies.get<Manager>().can(AppPermission.createReservation)
          ? FloatingActionButton.extended(
              heroTag: 'ajouter-reservation-calendriers',
              onPressed: _ajouterReservation,
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une réservation', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  /// Aucun bien n'est encore ouvert : on le choisit d'abord.
  Future<void> _ajouterReservation() async {
    final cree = await GoRouter.of(context).push(Routes.nouvelleReservation);
    if (cree == true && mounted) _charger();
  }

  Widget _corps() {
    if (_biens == null) {
      if (_chargement) return Center(child: MyLoadingIndicator());
      return MyErrorWidget(
        error: _erreur ?? "La liste des biens n'a pas pu être chargée.",
        action: 'Réessayer',
        actionCLick: _charger,
      );
    }

    final tous = _biens!;
    final biens = _filtrer(tous);

    return PageAEnTeteDefilant(
      entete: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8EC))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choisissez un bien pour ouvrir son calendrier',
                  style: TextStyle(fontSize: 13, color: _gris)),
              const SizedBox(height: 10),
              TextField(
                controller: _recherche,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Rechercher un bien, une référence, une adresse…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _recherche.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _recherche.clear,
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF2F5F7),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _recherche.text.trim().isEmpty
                        ? '${tous.length} bien${tous.length > 1 ? 's' : ''}'
                        : '${biens.length} sur ${tous.length}',
                    style: const TextStyle(fontSize: 12.5, color: _gris),
                  ),
                  const Spacer(),
                  if (_chargement)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_erreur != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 18, color: Color(0xFFB3261E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_erreur!,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF8C1D18))),
                ),
                TextButton(onPressed: _charger, child: const Text('Réessayer')),
              ],
            ),
          ),
      ],
      corps: RefreshIndicator(
        color: AppColors.primaryColor,
        onRefresh: _charger,
        child: biens.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(30),
                children: [
                  const SizedBox(height: 30),
                  const Icon(Icons.event_busy_outlined, size: 48, color: Color(0xFFB4C0C7)),
                  const SizedBox(height: 12),
                  Text(
                    tous.isEmpty
                        ? "Aucun bien pour l'instant."
                        : 'Aucun bien ne correspond à la recherche.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _gris),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                itemCount: biens.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _CarteBien(bien: biens[i], onTap: () => _ouvrir(biens[i])),
              ),
      ),
    );
  }
}

class _CarteBien extends StatelessWidget {
  final Realestate bien;
  final VoidCallback onTap;

  const _CarteBien({required this.bien, required this.onTap});

  static Color? _couleur(String? code) {
    if ((code ?? '').isEmpty) return null;
    try {
      return code!.toColor;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = (bien.media?.isNotEmpty ?? false) ? bien.media!.first.url : null;
    final lieu = [bien.secteur?.name, bien.address?.city?.name]
        .where((x) => (x ?? '').trim().isNotEmpty)
        .join(', ');
    final adresse = (bien.address?.address ?? '').trim();
    final statut = bien.status?.name;
    final couleurStatut = _couleur(bien.status?.color) ?? AppColors.primaryColor;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8EC)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (image ?? '').isNotEmpty
                    ? Image.network(image!,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _vignetteVide())
                    : _vignetteVide(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bien.title ?? 'Bien #${bien.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF17262E))),
                    if (lieu.isNotEmpty || adresse.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 14, color: Color(0xFF6B7B84)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(lieu.isNotEmpty ? lieu : adresse,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF4A5B64))),
                          ),
                        ],
                      ),
                    ],
                    // Statut du jour : disponible, occupe, a nettoyer…
                    if (bien.statutJour != null) ...[
                      const SizedBox(height: 6),
                      StatutBienChip(statut: bien.statutJour!, compact: true),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if ((statut ?? '').isNotEmpty)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: couleurStatut.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(statut!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: couleurStatut)),
                            ),
                          ),
                        const Spacer(),
                        Text('#${bien.id}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF98A6AE))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month_outlined, size: 20, color: Color(0xFF3B6FD4)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vignetteVide() => Container(
        width: 68,
        height: 68,
        color: const Color(0xFFEEF2F5),
        child: const Icon(Icons.home_outlined, color: Color(0xFF98A6AE)),
      );
}
