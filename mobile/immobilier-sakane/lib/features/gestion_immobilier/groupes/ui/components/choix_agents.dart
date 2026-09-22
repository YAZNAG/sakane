import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/repository/repository.dart';

/// Choix des agents autorisés sur un dossier.
///
/// Un dossier sans agent désigné reste visible de toute l'équipe. Dès
/// qu'un agent y est rattaché, seuls les agents rattachés — et les
/// administrateurs — voient ses biens.
class ChoixAgents extends StatefulWidget {
  final String nomDossier;
  final List<int> selection;

  const ChoixAgents({
    super.key,
    required this.nomDossier,
    required this.selection,
  });

  static Future<List<int>?> ouvrir(
    BuildContext context, {
    required String nomDossier,
    required List<int> selection,
  }) {
    return showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChoixAgents(nomDossier: nomDossier, selection: selection),
    );
  }

  @override
  State<ChoixAgents> createState() => _ChoixAgentsState();
}

class _ChoixAgentsState extends State<ChoixAgents> {
  late final Set<int> _retenus = {...widget.selection};
  List<Manager>? _managers;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final liste = await Dependencies.get<Repository>().getManagers();
      if (!mounted) return;
      setState(() => _managers = liste);
    } catch (_) {
      if (!mounted) return;
      setState(() => _erreur = "Impossible de charger l'équipe");
    }
  }

  /// Les administrateurs voient tout : les rattacher n'aurait aucun effet.
  bool _estAdmin(Manager m) => m.roles?.contains('admin') ?? false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, controleur) => Column(
        children: [
          _entete(),
          const Divider(height: 1),
          Expanded(child: _contenu(controleur)),
          _pied(),
        ],
      ),
    );
  }

  Widget _entete() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Agents autorisés",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: "Fermer sans enregistrer",
              ),
            ],
          ),
          Text(
            "Dossier « ${widget.nomDossier} »",
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _retenus.isEmpty
                  ? Colors.blue.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _retenus.isEmpty ? Icons.groups_outlined : Icons.lock_outline,
                  size: 17,
                  color: _retenus.isEmpty
                      ? Colors.blue.shade800
                      : Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _retenus.isEmpty
                        ? "Aucun agent désigné : le dossier reste visible de toute l'équipe."
                        : "Seuls les agents cochés verront les biens de ce dossier. "
                            "Les administrateurs y accèdent toujours.",
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: _retenus.isEmpty
                          ? Colors.blue.shade900
                          : Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenu(ScrollController controleur) {
    if (_erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_erreur!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700)),
        ),
      );
    }

    if (_managers == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final equipe = _managers!.where((m) => !_estAdmin(m)).toList();

    if (equipe.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            "Aucun agent enregistré. Les administrateurs accèdent déjà à tout.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: controleur,
      itemCount: equipe.length,
      itemBuilder: (context, i) {
        final m = equipe[i];
        return CheckboxListTile(
          value: _retenus.contains(m.id),
          onChanged: m.id == null
              ? null
              : (v) => setState(() {
                    if (v == true) {
                      _retenus.add(m.id!);
                    } else {
                      _retenus.remove(m.id);
                    }
                  }),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            "${m.firstName ?? ''} ${m.lastName ?? ''}".trim(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            [
              if ((m.roles ?? []).isNotEmpty) m.roles!.join(', '),
              if (m.email != null) m.email!,
            ].join(' · '),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        );
      },
    );
  }

  Widget _pied() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_retenus.toList()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              _retenus.isEmpty
                  ? "Ouvrir à toute l'équipe"
                  : "Autoriser ${_retenus.length} agent${_retenus.length > 1 ? 's' : ''}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
