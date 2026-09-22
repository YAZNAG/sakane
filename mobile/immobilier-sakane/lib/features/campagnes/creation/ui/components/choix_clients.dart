import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/models/client.dart';

/// Choix manuel des destinataires d'une campagne.
///
/// Affiche tous les clients, y compris ceux qui ne peuvent pas recevoir
/// de message : les masquer laisserait le gérant chercher en vain
/// quelqu'un qui figure bien dans son fichier. Le motif est indiqué, et
/// leur sélection est refusée.
class ChoixClients extends StatefulWidget {
  final List<Client> clients;
  final List<int> selection;

  const ChoixClients({
    super.key,
    required this.clients,
    required this.selection,
  });

  /// Ouvre la feuille de sélection. Renvoie la liste retenue, ou null
  /// si le gérant a refermé sans valider.
  static Future<List<int>?> ouvrir(
    BuildContext context, {
    required List<Client> clients,
    required List<int> selection,
  }) {
    return showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChoixClients(clients: clients, selection: selection),
    );
  }

  @override
  State<ChoixClients> createState() => _ChoixClientsState();
}

class _ChoixClientsState extends State<ChoixClients> {
  late final Set<int> _retenus = {...widget.selection};
  final _recherche = TextEditingController();
  String _filtre = '';

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  /// Un client est joignable s'il a un numéro exploitable et n'a pas
  /// refusé les messages promotionnels.
  bool _joignable(Client c) =>
      c.acceptePromotions && _numeroValide(c.tel);

  /// Neuf chiffres après l'indicatif : même règle que le serveur.
  bool _numeroValide(String? tel) {
    final chiffres = (tel ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    return chiffres.length >= 9;
  }

  String? _motifExclusion(Client c) {
    if (!_numeroValide(c.tel)) return "Numéro manquant ou incomplet";
    if (!c.acceptePromotions) return "Refuse les messages promotionnels";
    return null;
  }

  List<Client> get _visibles {
    if (_filtre.isEmpty) return widget.clients;
    final q = _filtre.toLowerCase();
    return widget.clients.where((c) {
      final nom = "${c.firstName ?? ''} ${c.lastName ?? ''}".toLowerCase();
      return nom.contains(q) || (c.tel ?? '').contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final joignables = widget.clients.where(_joignable).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controleur) => Column(
        children: [
          _entete(joignables.length),
          _barreRecherche(),
          _actionsGroupees(joignables),
          const Divider(height: 1),
          Expanded(child: _liste(controleur)),
          _pied(),
        ],
      ),
    );
  }

  Widget _entete(int nbJoignables) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Choisir les destinataires",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  "$nbJoignables client${nbJoignables > 1 ? 's' : ''} "
                  "joignable${nbJoignables > 1 ? 's' : ''} "
                  "sur ${widget.clients.length}",
                  style:
                      TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: "Fermer sans enregistrer",
          ),
        ],
      ),
    );
  }

  Widget _barreRecherche() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _recherche,
        onChanged: (v) => setState(() => _filtre = v.trim()),
        decoration: InputDecoration(
          hintText: "Rechercher un nom ou un numéro…",
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _filtre.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _recherche.clear();
                    setState(() => _filtre = '');
                  },
                ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _actionsGroupees(List<Client> joignables) {
    final tousRetenus = joignables.isNotEmpty &&
        joignables.every((c) => _retenus.contains(c.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: joignables.isEmpty
                ? null
                : () => setState(() {
                      if (tousRetenus) {
                        _retenus.removeWhere(
                            (id) => joignables.any((c) => c.id == id));
                      } else {
                        _retenus.addAll(
                            joignables.map((c) => c.id!).where((id) => true));
                      }
                    }),
            icon: Icon(
                tousRetenus
                    ? Icons.check_box_outline_blank
                    : Icons.select_all,
                size: 18),
            label: Text(
              tousRetenus ? "Tout désélectionner" : "Tout sélectionner",
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              "${_retenus.length} retenu${_retenus.length > 1 ? 's' : ''}",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _retenus.isEmpty
                    ? Colors.grey.shade600
                    : AppColors.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _liste(ScrollController controleur) {
    final visibles = _visibles;

    if (visibles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _filtre.isEmpty
                ? "Aucun client enregistré."
                : "Aucun client ne correspond à « $_filtre »。",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: controleur,
      itemCount: visibles.length,
      itemBuilder: (context, i) {
        final client = visibles[i];
        final motif = _motifExclusion(client);
        final joignable = motif == null;
        final retenu = _retenus.contains(client.id);

        return CheckboxListTile(
          value: retenu && joignable,
          onChanged: joignable && client.id != null
              ? (v) => setState(() {
                    if (v == true) {
                      _retenus.add(client.id!);
                    } else {
                      _retenus.remove(client.id);
                    }
                  })
              : null,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            "${client.firstName ?? ''} ${client.lastName ?? ''}".trim(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: joignable ? Colors.black87 : Colors.grey.shade500,
            ),
          ),
          subtitle: Text(
            motif ?? (client.tel ?? ''),
            style: TextStyle(
              fontSize: 12,
              color: joignable ? Colors.grey.shade600 : Colors.orange.shade800,
            ),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              _retenus.isEmpty
                  ? "Valider sans destinataire"
                  : "Valider ${_retenus.length} destinataire"
                      "${_retenus.length > 1 ? 's' : ''}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
