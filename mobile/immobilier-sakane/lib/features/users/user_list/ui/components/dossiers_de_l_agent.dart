import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/dossier.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/repository/repository.dart';

/// Dossiers auxquels un agent a accès, réglés depuis sa fiche.
///
/// Un agent sans dossier désigné garde l'accès à tout le parc : c'est le
/// comportement d'origine, et le restreindre sans le vouloir priverait
/// quelqu'un de son outil de travail.
class DossiersDeLAgent extends StatefulWidget {
  final Manager agent;

  const DossiersDeLAgent({super.key, required this.agent});

  static Future<bool?> ouvrir(BuildContext context, Manager agent) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DossiersDeLAgent(agent: agent),
    );
  }

  @override
  State<DossiersDeLAgent> createState() => _DossiersDeLAgentState();
}

class _DossiersDeLAgentState extends State<DossiersDeLAgent> {
  final Set<int> _retenus = {};
  List<Dossier>? _tous;
  String? _erreur;
  bool _enregistrement = false;

  Repository get _repository => Dependencies.get<Repository>();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final resultats = await Future.wait([
        _repository.fetchDossiers(),
        _repository.dossiersDeLAgent(widget.agent.id!),
      ]);
      if (!mounted) return;
      setState(() {
        _tous = resultats[0];
        _retenus
          ..clear()
          ..addAll(resultats[1].where((d) => d.id != null).map((d) => d.id!));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _erreur = "Impossible de charger les dossiers");
    }
  }

  String _famille(String? code) {
    switch (code) {
      case 'rent-short':
        return 'Location courte durée';
      case 'rent-long':
        return 'Location longue durée';
      case 'selle':
        return 'Vente';
      default:
        return 'Sans catégorie';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nom =
        "${widget.agent.firstName ?? ''} ${widget.agent.lastName ?? ''}".trim();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.94,
      builder: (context, controleur) => Column(
        children: [
          _entete(nom),
          const Divider(height: 1),
          Expanded(child: _contenu(controleur)),
          _pied(),
        ],
      ),
    );
  }

  Widget _entete(String nom) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text("Dossiers accessibles",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close),
                tooltip: "Fermer sans enregistrer",
              ),
            ],
          ),
          Text(nom,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  _retenus.isEmpty ? Colors.blue.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _retenus.isEmpty ? Icons.public : Icons.lock_outline,
                  size: 17,
                  color: _retenus.isEmpty
                      ? Colors.blue.shade800
                      : Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _retenus.isEmpty
                        ? "Aucun dossier coché : cet agent accède à tous les biens."
                        : "Cet agent ne verra que les biens des dossiers cochés.",
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

    if (_tous == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tous!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            "Aucun dossier n'a encore été créé.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
          ),
        ),
      );
    }

    // Regroupés par famille : c'est ainsi qu'ils sont parcourus dans
    // l'application, la lecture reste cohérente.
    final parFamille = <String, List<Dossier>>{};
    for (final d in _tous!) {
      parFamille.putIfAbsent(_famille(d.typeCode), () => []).add(d);
    }

    return ListView(
      controller: controleur,
      children: parFamille.entries.expand((groupe) {
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              groupe.key,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700),
            ),
          ),
          ...groupe.value.map((d) => CheckboxListTile(
                value: _retenus.contains(d.id),
                onChanged: d.id == null
                    ? null
                    : (v) => setState(() {
                          if (v == true) {
                            _retenus.add(d.id!);
                          } else {
                            _retenus.remove(d.id);
                          }
                        }),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(d.nom ?? '',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text("${d.nombreBiens} bien(s)",
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              )),
        ];
      }).toList(),
    );
  }

  Widget _pied() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _enregistrement ? null : _enregistrer,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _enregistrement
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    _retenus.isEmpty
                        ? "Donner accès à tout le parc"
                        : "Limiter à ${_retenus.length} dossier${_retenus.length > 1 ? 's' : ''}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  void _enregistrer() async {
    setState(() => _enregistrement = true);
    try {
      await _repository.majDossiersDeLAgent(
          widget.agent.id!, _retenus.toList());
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enregistrement = false;
        _erreur = "L'enregistrement n'a pas abouti";
      });
    }
  }
}
