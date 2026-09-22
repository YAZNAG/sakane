import 'package:immobilier/components/entete_defilant.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/routes.dart';

/// Nouvelle réservation, première étape : choisir le bien.
///
/// Le formulaire de réservation part toujours d'un bien : on le choisit
/// ici, par une recherche, avant d'ouvrir le formulaire.
class ChoixBienReservationPage extends StatefulWidget {
  const ChoixBienReservationPage({super.key});

  @override
  State<ChoixBienReservationPage> createState() => _ChoixBienReservationPageState();
}

class _ChoixBienReservationPageState extends State<ChoixBienReservationPage> {
  late Future<List<Object?>> _chargement;
  final _recherche = TextEditingController();
  bool _disponiblesSeulement = false;

  @override
  void initState() {
    super.initState();
    _chargement = _charger();
    _recherche.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<List<Object?>> _charger() {
    final depot = Dependencies.get<Repository>();
    return Future.wait<Object?>([
      depot.getRealestates(),
      _disponibles(depot),
    ]);
  }

  /// Les biens disponibles, selon la même règle que l'écran « Biens
  /// disponibles » : pas de séjour en cours et appartement nettoyé.
  /// Nul si la liste n'a pas pu être obtenue (droit manquant, réseau).
  static Future<Set<int>?> _disponibles(Repository depot) async {
    try {
      final liste = await depot.getRealestates(status: 'available');
      return liste.map((r) => r.id).whereType<int>().toSet();
    } catch (_) {
      return null;
    }
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

  List<Realestate> _filtrer(List<Realestate> tous, Set<int>? disponibles) {
    final q = _sansAccents(_recherche.text.trim());
    return tous.where((r) {
      if (_disponiblesSeulement && !(disponibles?.contains(r.id) ?? false)) return false;
      if (q.isEmpty) return true;
      final texte = _sansAccents([
        r.title,
        r.address?.address,
        r.address?.city?.name,
        r.owner?.name,
        '${r.id}',
      ].whereType<String>().join(' '));
      return texte.contains(q);
    }).toList();
  }

  Future<void> _choisir(Realestate bien) async {
    await GoRouter.of(context)
        .push(Routes.addReservation.replaceFirst(':id', '${bien.id}'));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F7),
      appBar: AppBar(
        title: const Text('Nouvelle réservation',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List<Object?>>(
        future: _chargement,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: MyLoadingIndicator());
          }
          if (snap.hasError) {
            return MyErrorWidget(
              error: "La liste des biens n'a pas pu être chargée.",
              action: 'Réessayer',
              actionCLick: () => setState(() => _chargement = _charger()),
            );
          }

          final tous = (snap.data?[0] as List<Realestate>?) ?? const <Realestate>[];
          final disponibles = snap.data?[1] as Set<int>?;
          final biens = _filtrer(tous, disponibles);

          return PageAEnTeteDefilant(
            entete: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8EC))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _Etape(numero: 1, libelle: 'Bien', active: true),
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            color: const Color(0xFFD5DDE2),
                          ),
                        ),
                        const _Etape(numero: 2, libelle: 'Client & séjour', active: false),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _recherche,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un bien, une adresse, une ville…',
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Tous'),
                          selected: !_disponiblesSeulement,
                          onSelected: (_) => setState(() => _disponiblesSeulement = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(disponibles == null
                              ? 'Disponibles'
                              : 'Disponibles (${tous.where((r) => disponibles.contains(r.id)).length})'),
                          selected: _disponiblesSeulement,
                          onSelected: disponibles == null
                              ? null
                              : (_) => setState(() => _disponiblesSeulement = true),
                        ),
                        const Spacer(),
                        Text('${biens.length} bien${biens.length > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7B84))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            corps: biens.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Text(
                              _disponiblesSeulement
                                  ? 'Aucun bien disponible en ce moment.'
                                  : 'Aucun bien ne correspond à la recherche.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF6B7B84))),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                        itemCount: biens.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _CarteBien(
                          bien: biens[i],
                          disponible: disponibles?.contains(biens[i].id),
                          onTap: () => _choisir(biens[i]),
                        ),
                      ),
          );
        },
      ),
    );
  }
}

class _Etape extends StatelessWidget {
  final int numero;
  final String libelle;
  final bool active;

  const _Etape({required this.numero, required this.libelle, required this.active});

  @override
  Widget build(BuildContext context) {
    final couleur = active ? AppColors.primaryColor : const Color(0xFF98A6AE);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? couleur : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: couleur, width: 1.5),
          ),
          child: Text('$numero',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : couleur)),
        ),
        const SizedBox(width: 6),
        Text(libelle,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? const Color(0xFF17262E) : couleur)),
      ],
    );
  }
}

class _CarteBien extends StatelessWidget {
  final Realestate bien;

  /// Disponible maintenant ? Nul quand on ne le sait pas.
  final bool? disponible;
  final VoidCallback onTap;

  const _CarteBien({required this.bien, required this.disponible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = (bien.media?.isNotEmpty ?? false) ? bien.media!.first.url : null;
    final adresse = [bien.address?.address, bien.address?.city?.name]
        .where((x) => (x ?? '').trim().isNotEmpty)
        .join(', ');
    final couleurEtat = disponible == true ? const Color(0xFF2E8B45) : const Color(0xFFA8542B);

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
                child: image != null
                    ? Image.network(image,
                        width: 72,
                        height: 72,
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
                    if (adresse.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 14, color: Color(0xFF6B7B84)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(adresse,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF4A5B64))),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (disponible != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: couleurEtat.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(disponible! ? 'Disponible' : 'Occupé ou à nettoyer',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600, color: couleurEtat)),
                          ),
                        const Spacer(),
                        if (bien.price != null)
                          Text('${bien.price} MAD',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryColor)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Color(0xFF98A6AE)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vignetteVide() => Container(
        width: 72,
        height: 72,
        color: const Color(0xFFEEF2F5),
        child: const Icon(Icons.home_outlined, color: Color(0xFF98A6AE)),
      );
}
