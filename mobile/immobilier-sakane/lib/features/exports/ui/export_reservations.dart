import 'package:immobilier/components/entete_defilant.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/exports/cubit/export_reservations_cubit.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

/// Export des réservations, par bien ou par client.
///
/// La sélection est multiple des deux côtés : trois appartements, ou
/// deux clients, s'exportent en une fois. Sans rien de coché, l'export
/// porte sur tout ce que l'agent a le droit de voir.
class ExportReservationsPage extends StatelessWidget {
  const ExportReservationsPage({super.key});

  static Widget page() => BlocProvider(
        create: (_) => ExportReservationsCubit()..charger(),
        child: const ExportReservationsPage(),
      );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExportReservationsCubit, ExportReservationsState>(
      listenWhen: (a, b) => a.exportation != b.exportation,
      listener: (context, state) {
        if (state.exportation == AppStatus.success && state.fichier != null) {
          _proposerFichier(context, state.fichier!);
        } else if (state.exportation == AppStatus.error) {
          showToast("Export impossible", context,
              description:
                  state.erreur ?? "Le fichier n'a pas pu être produit.",
              type: ToastificationType.error,
              second: 6);
        }
      },
      builder: (context, state) {
        final cubit = context.read<ExportReservationsCubit>();

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: const Text("Export des réservations",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            centerTitle: true,
            elevation: 0,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryColor,
          ),
          body: state.chargement == AppStatus.loading
              ? Center(child: MyLoadingIndicator())
              : PageAEnTeteDefilant(
                  entete: [
                    _selecteurAxe(context, state),
                    _periode(context, state),
                    _barreRecherche(context, state),
                  ],
                  corps: _liste(context, state),
                ),
          bottomNavigationBar: state.chargement == AppStatus.loading
              ? null
              : _piedDePage(context, state, cubit),
        );
      },
    );
  }

  // ── Axe : biens ou clients ────────────────────────────────────────

  Widget _selecteurAxe(BuildContext context, ExportReservationsState state) {
    final cubit = context.read<ExportReservationsCubit>();

    Widget onglet(AxeExport axe, String titre, IconData icone, int coches) {
      final actif = state.axe == axe;
      return Expanded(
        child: InkWell(
          onTap: () => cubit.changerAxe(axe),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: actif ? AppColors.primaryColor : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone,
                    size: 18,
                    color: actif ? AppColors.primaryColor : Colors.grey),
                const SizedBox(width: 7),
                Text(
                  titre,
                  style: TextStyle(
                    fontWeight: actif ? FontWeight.bold : FontWeight.w500,
                    color: actif ? AppColors.primaryColor : Colors.grey.shade700,
                  ),
                ),
                if (coches > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text("$coches",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Row(
        children: [
          onglet(AxeExport.biens, "Par bien", Icons.home_work_outlined,
              state.biensChoisis.length),
          onglet(AxeExport.clients, "Par client", Icons.people_outline,
              state.clientsChoisis.length),
        ],
      ),
    );
  }

  // ── Période ───────────────────────────────────────────────────────

  Widget _periode(BuildContext context, ExportReservationsState state) {
    final cubit = context.read<ExportReservationsCubit>();
    final definie = state.du != null || state.au != null;

    Future<void> choisir(bool debut) async {
      final initiale = (debut ? state.du : state.au) ??
          (debut ? state.au : state.du) ??
          DateTime.now();

      final choisie = await showDatePicker(
        context: context,
        initialDate: initiale,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 730)),
        helpText: debut ? "Date de début" : "Date de fin",
      );
      if (choisie == null) return;

      // Une fin antérieure au début ne filtre rien : on remet les deux
      // bornes dans l'ordre plutôt que de rendre une liste vide.
      var du = debut ? choisie : state.du;
      var au = debut ? state.au : choisie;
      if (du != null && au != null && au.isBefore(du)) {
        final tampon = du;
        du = au;
        au = tampon;
      }
      cubit.definirPeriode(du, au);
    }

    Widget champ(String libelle, DateTime? valeur, bool debut) {
      return Expanded(
        child: InkWell(
          onTap: () => choisir(debut),
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(
                color: valeur == null
                    ? Colors.grey.shade300
                    : AppColors.primaryColor.withValues(alpha: .5),
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Icon(Icons.event,
                    size: 17,
                    color: valeur == null
                        ? Colors.grey.shade500
                        : AppColors.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(libelle,
                          style: TextStyle(
                              fontSize: 10.5, color: Colors.grey.shade600)),
                      Text(
                        valeur == null ? "Toutes" : _jour(valeur),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: valeur == null
                              ? Colors.grey.shade600
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          champ("Date de début", state.du, true),
          const SizedBox(width: 10),
          champ("Date de fin", state.au, false),
          if (definie)
            IconButton(
              tooltip: "Retirer la période",
              onPressed: () => cubit.definirPeriode(null, null),
              icon: Icon(Icons.close, size: 19, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  // ── Recherche et tout cocher ──────────────────────────────────────

  Widget _barreRecherche(BuildContext context, ExportReservationsState state) {
    final cubit = context.read<ExportReservationsCubit>();
    final nbVisibles = state.axe == AxeExport.biens
        ? state.biensFiltres.length
        : state.clientsFiltres.length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: cubit.rechercher,
              decoration: InputDecoration(
                isDense: true,
                hintText: state.axe == AxeExport.biens
                    ? "Rechercher un bien"
                    : "Rechercher un client",
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          TextButton(
            onPressed: nbVisibles == 0 ? null : cubit.toutBasculer,
            child: const Text("Tout"),
          ),
        ],
      ),
    );
  }

  // ── La liste ──────────────────────────────────────────────────────

  Widget _liste(BuildContext context, ExportReservationsState state) {
    final cubit = context.read<ExportReservationsCubit>();

    if (state.chargement == AppStatus.error) {
      return _message(Icons.wifi_off, "Les listes n'ont pas pu être chargées",
          "Vérifiez votre connexion, puis réessayez.");
    }

    if (state.axe == AxeExport.biens) {
      final biens = state.biensFiltres;
      if (biens.isEmpty) {
        return _message(Icons.home_work_outlined, "Aucun bien",
            "Aucun bien ne correspond à cette recherche.");
      }
      return ListView.builder(
        padding: const EdgeInsets.only(top: 6, bottom: 12),
        itemCount: biens.length,
        itemBuilder: (_, i) {
          final b = biens[i];
          final coche = b.id != null && state.biensChoisis.contains(b.id);
          return CheckboxListTile(
            value: coche,
            onChanged: b.id == null ? null : (_) => cubit.basculerBien(b.id!),
            title: Text(b.title ?? "Bien sans titre",
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                if (b.secteur?.name?.isNotEmpty == true) b.secteur!.name!,
                if (b.address?.city?.name?.isNotEmpty == true)
                  b.address!.city!.name!,
              ].join(" · "),
              style: const TextStyle(fontSize: 12),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          );
        },
      );
    }

    final clients = state.clientsFiltres;
    if (clients.isEmpty) {
      return _message(Icons.people_outline, "Aucun client",
          "Aucun client ne correspond à cette recherche.");
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      itemCount: clients.length,
      itemBuilder: (_, i) {
        final c = clients[i];
        final coche = c.id != null && state.clientsChoisis.contains(c.id);
        final nom = "${c.firstName ?? ''} ${c.lastName ?? ''}".trim();
        return CheckboxListTile(
          value: coche,
          onChanged: c.id == null ? null : (_) => cubit.basculerClient(c.id!),
          title: Text(nom.isEmpty ? "Client sans nom" : nom,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(c.tel ?? "—", style: const TextStyle(fontSize: 12)),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        );
      },
    );
  }

  Widget _message(IconData icone, String titre, String detail) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 50, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(titre,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Text(detail,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        ),
      );

  // ── Pied de page ──────────────────────────────────────────────────

  Widget _piedDePage(BuildContext context, ExportReservationsState state,
      ExportReservationsCubit cubit) {
    final enCours = state.exportation == AppStatus.loading;
    final total = state.biensChoisis.length + state.clientsChoisis.length;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    state.toutExporter
                        ? "Rien de coché : toutes les réservations seront exportées."
                        : "$total sélection${total > 1 ? 's' : ''} — "
                            "${state.biensChoisis.length} bien(s), "
                            "${state.clientsChoisis.length} client(s)",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
                if (total > 0)
                  TextButton(
                    onPressed: cubit.effacerSelection,
                    child: const Text("Effacer"),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: enCours ? null : () => cubit.exporter("xlsx"),
                    icon: const Icon(Icons.table_chart_outlined, size: 19),
                    label: const Text("Excel"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: enCours ? null : () => cubit.exporter("pdf"),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 19),
                    label: const Text("PDF"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
            if (enCours) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 4),
              Text("Préparation du fichier…",
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Une fois le fichier prêt ──────────────────────────────────────

  void _proposerFichier(BuildContext context, String chemin) {
    final nom = chemin.split(Platform.pathSeparator).last;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (feuille) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text("Fichier prêt",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(nom,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text("Ouvrir"),
              onTap: () {
                Navigator.pop(feuille);
                OpenFile.open(chemin);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text("Partager"),
              onTap: () {
                Navigator.pop(feuille);
                SharePlus.instance.share(ShareParams(
                  files: [XFile(chemin)],
                  subject: "Liste des réservations",
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  String _jour(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/"
      "${d.month.toString().padLeft(2, '0')}/${d.year}";
}
