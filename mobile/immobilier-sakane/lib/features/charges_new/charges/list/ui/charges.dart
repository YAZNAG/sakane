import 'package:immobilier/components/entete_defilant.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/form_field.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/models/charge.dart';
import 'package:immobilier/models/manager.dart';
import 'package:toastification/toastification.dart';

import '../../../../../routes.dart';
import '../cubit/charges_cubit.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/components/images_galery.dart';
import 'package:immobilier/models/media.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

class ChargesPage extends StatefulWidget {
  final int? propertyId;
  ChargesPage({this.propertyId}) ;

  static Widget page({int? realestate}) => BlocProvider<ChargesCubit>(
    create: (ctx) => ChargesCubit(realestate: realestate),
    child:  ChargesPage(propertyId: realestate,),
  );

  @override
  State<ChargesPage> createState() => _ChargesPageState();
}

class _ChargesPageState extends State<ChargesPage> {

  TableauExportable? _tableauExport() {
    final state = context.read<ChargesCubit>().state;
    final liste = state.charges;
    if (liste == null) return null;
    const statuts = {'payed': 'Payée', 'pending': 'En attente', 'cancelled': 'Annulée'};
    double total = 0;
    final lignes = liste.map((c) {
      total += c.amount ?? 0;
      return [
        dateExport(c.createdAt),
        c.nom ?? '',
        c.description ?? '',
        c.realEstate?.title ?? 'Agence',
        c.type == 'variable' ? 'Variable' : (c.type == null ? '' : 'Fixe'),
        statuts[c.status] ?? (c.status ?? ''),
        c.creePar ?? '',
        montantExport(c.amount),
      ];
    }).toList();
    final periode = state.from == null || state.to == null
        ? null
        : 'Du ${dateExport(state.from)} au ${dateExport(state.to)}';
    return TableauExportable(
      titre: 'Charges',
      sousTitre: [_libelleBien(state), if (periode != null) periode].join(' • '),
      colonnes: const ['Date', 'Nom', 'Description', 'Bien', 'Type', 'Statut', 'Saisie par', 'Montant'],
      lignes: lignes,
      totaux: ['TOTAL', '', '', '', '', '', '', montantExport(total)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Charges',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [BoutonExport(tableau: _tableauExport)],
      ),
      floatingActionButton: !Dependencies.get<Manager>().can(AppPermission.createCharge) ? null : FloatingActionButton(
        onPressed: () async{
          final route=Routes.addCharge + (widget.propertyId!=null?"?realestate=${widget.propertyId}":"");
          await GoRouter.of(context).push(route);
          fetchData();
        },
        backgroundColor: AppColors.primaryColor,
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: BlocConsumer<ChargesCubit, ChargesState>(
        listener: _listener,
        builder: (context, state) => _buildContent(state),
      ),
    );
  }

  Widget _buildContent(ChargesState state) {
    if (state.fetchStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchStatus == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? "Erreur",
        action: AppStrings.tryAgain,
        actionCLick: () => BlocProvider.of<ChargesCubit>(context).fetchData(),
      );
    } else if (state.fetchStatus == AppStatus.success) {
      return PageAEnTeteDefilant(
        entete: [
          _buildFilters(state),
        ],
        corps: state.charges == null || state.charges!.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
              padding: EdgeInsets.all(16),
              itemCount: state.charges!.length,
              separatorBuilder: (_, __) => SizedBox(height: 12),
              itemBuilder: (_, index) =>
                  _buildChargeCard(state.charges![index]),
            ),
      );
    }
    return SizedBox();
  }

  Widget _buildFilters(ChargesState state) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Date filters
          Row(
            children: [
              Expanded(
                child: MyFormField(
                  label: "",
                  hint: "Date début",
                  readOnly: true,
                  borderColor: Colors.black,
                  activeBorderColor: Colors.black,
                  labelColor: Colors.black,
                  controller: TextEditingController()
                    ..text = state.from?.formattedDateFr ?? "",
                  onTap: () => _pickDate(
                    initialDate: state.from ?? DateTime.now(),
                    onPicked: (dt) =>
                        BlocProvider.of<ChargesCubit>(context).pickDate("from", dt),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: Colors.grey.shade600),
              ),
              Expanded(
                child: MyFormField(
                  label: "",
                  hint: "Date fin",
                  readOnly: true,
                  borderColor: Colors.black,
                  activeBorderColor: Colors.black,
                  labelColor: Colors.black,
                  controller: TextEditingController()
                    ..text = state.to?.formattedDateFr ?? "",
                  onTap: () => _pickDate(
                    initialDate: state.to ?? DateTime.now(),
                    onPicked: (dt) =>
                        BlocProvider.of<ChargesCubit>(context).pickDate("to", dt),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () =>
                      BlocProvider.of<ChargesCubit>(context).fetchData(),
                  icon: Icon(Icons.search, color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Appartement : charges de l'agence, toutes, ou un appartement
          _buildFiltreBien(state),
          SizedBox(height: 12),

          // Type & Status filters
          Row(
            children: [
              Expanded(
                child: _buildDropdownFilter(
                  hint: "Type",
                  value: state.type,
                  items: {
                    "fix": "Fixe",
                    "variable": "Variable",
                  },
                  onChanged: (val) {
                    BlocProvider.of<ChargesCubit>(context).setType(val);
                    BlocProvider.of<ChargesCubit>(context).fetchData();
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDropdownFilter(
                  hint: "Statut",
                  value: state.status,
                  items: {
                    "pending": "En attente",
                    "payed": "Payée",
                    "cancelled": "Annulée",
                  },
                  onChanged: (val) {
                    BlocProvider.of<ChargesCubit>(context).setStatus(val);
                    BlocProvider.of<ChargesCubit>(context).fetchData();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _libelleBien(ChargesState state) {
    if (state.bien == "agence") return "Charges de l'agence";
    if (state.bien == "all") return "Toutes les charges";
    final bien = state.biens?.where((b) => b.id?.toString() == state.bien).firstOrNull;
    return bien?.title ?? "Appartement n° ${state.bien}";
  }

  Widget _buildFiltreBien(ChargesState state) {
    final biens = state.biens ?? const [];
    final valeurs = <String>{"agence", "all", ...biens.map((b) => b.id.toString())};
    // Le bien ouvert depuis sa fiche reste choisi meme avant que la liste arrive.
    final valeur = valeurs.contains(state.bien) ? state.bien : null;

    return DropdownButtonFormField<String>(
      value: valeur,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.apartment, size: 20, color: AppColors.primaryColor),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      hint: Text(_libelleBien(state), style: TextStyle(fontSize: 13)),
      items: [
        DropdownMenuItem(value: "agence", child: Text("Charges de l'agence")),
        DropdownMenuItem(value: "all", child: Text("Toutes les charges")),
        ...biens.map((b) => DropdownMenuItem(
              value: b.id.toString(),
              child: Text(b.title ?? "Appartement n° ${b.id}", overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: (val) {
        if (val != null) BlocProvider.of<ChargesCubit>(context).setBien(val);
      },
    );
  }

  Widget _buildDropdownFilter({
    required String hint,
    required String? value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      hint: Text(hint, style: TextStyle(fontSize: 13)),
      items: [
        DropdownMenuItem(value: null, child: Text("Tous")),
        ...items.entries.map(
              (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
        ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildChargeCard(Charge charge) {
    final statusInfo = _getStatusInfo(charge.status);
    final isVariable = charge.type == "variable";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.receipt_long,
                      color: Colors.orange.shade700, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        charge.nom ?? "-",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2),
                      if (charge.createdAt != null)
                        Text(
                          charge.createdAt!.formattedDateFr,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      // Qui a saisi la depense : la question se pose des
                      // qu'un montant surprend.
                      if ((charge.creePar ?? "").isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: 13, color: Colors.grey.shade600),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  charge.creePar!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  "${charge.amount?.toStringAsFixed(2) ?? '0.00'} MAD",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                // Status badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo["color"] as Color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusInfo["label"] as String,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(width: 8),
                // Type badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isVariable
                        ? Colors.purple.shade100
                        : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isVariable ? "Variable" : "Fixe",
                    style: TextStyle(
                      fontSize: 11,
                      color: isVariable
                          ? Colors.purple.shade700
                          : AppColors.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Spacer(),

                // Une charge ne s'efface plus : elle s'annule, et ce
                // qui est rendu revient en caisse.
                if (Dependencies.get<Manager>().can(AppPermission.cancelCharge))
                IconButton(
                  icon: Icon(Icons.block_outlined,
                      color: Colors.red.shade400, size: 20),
                  tooltip: 'Annuler la charge',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () => _annulerCharge(charge),
                ),
                SizedBox(width: 4),

                // Validate button for pending charges
                if (charge.status == "pending" && Dependencies.get<Manager>().can(AppPermission.validateCharge))
                  ElevatedButton.icon(
                    onPressed: () => _showValidateBottomSheet(charge),
                    icon: Icon(Icons.check_circle_outline,
                        size: 16, color: Colors.white),
                    label: Text("Valider",
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),

            // Piece jointe : recu, facture ou justificatif
            if (charge.documentFile != null) ...[
              SizedBox(height: 10),
              Divider(height: 1),
              SizedBox(height: 10),
              _buildPieceJointe(charge),
            ],
          ],
        ),
      ),
    );
  }

  /// Affiche le recu / la facture attachee a une charge.
  /// Une image s'ouvre en plein ecran, un PDF dans la visionneuse du telephone.
  Widget _buildPieceJointe(Charge charge) {
    final doc = charge.documentFile!;
    final estImage = doc.isImage;

    return InkWell(
      onTap: () => _ouvrirPieceJointe(doc),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            if (estImage && doc.url != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  doc.url!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.image_outlined,
                    color: AppColors.primaryColor,
                  ),
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.picture_as_pdf_outlined,
                    color: Colors.red.shade600),
              ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    estImage ? "Reçu / justificatif" : "Facture (PDF)",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    doc.tailleLisible,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 18, color: AppColors.primaryColor),
          ],
        ),
      ),
    );
  }

  Future<void> _ouvrirPieceJointe(dynamic doc) async {
    if (doc.url == null) return;

    if (doc.isImage == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImagesGalery(
            medias: [Media(id: doc.id, url: doc.url)],
          ),
        ),
      );
      return;
    }

    // PDF : telechargement puis ouverture avec la visionneuse du telephone
    try {
      final dossier = await getTemporaryDirectory();
      final chemin =
          "${dossier.path}/${doc.name ?? 'document_${DateTime.now().millisecondsSinceEpoch}.pdf'}";
      await Dio().download(doc.url!, chemin);
      await OpenFile.open(chemin);
    } catch (_) {
      if (mounted) {
        showToast("Impossible d'ouvrir le document", context,
            type: ToastificationType.error);
      }
    }
  }

  Map<String, dynamic> _getStatusInfo(String? status) {
    switch (status) {
      case "payed":
        return {"label": "Payée", "color": Colors.green.shade600};
      case "pending":
        return {"label": "En attente", "color": Colors.orange.shade600};
      case "cancelled":
        return {"label": "Annulée", "color": Colors.red.shade600};
      default:
        return {"label": "-", "color": Colors.grey};
    }
  }

  void _showValidateBottomSheet(Charge charge) {
    File? selectedDocument;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Valider la charge",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Vous pouvez joindre un document justificatif (optionnel)",
                    style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 20),

                  // Document picker
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                          source: ImageSource.gallery);
                      if (picked != null) {
                        setSheetState(
                                () => selectedDocument = File(picked.path));
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedDocument != null
                              ? Colors.green.shade400
                              : Colors.grey.shade300,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedDocument != null
                                ? Icons.check_circle
                                : Icons.upload_file,
                            color: selectedDocument != null
                                ? Colors.green.shade600
                                : Colors.grey.shade500,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedDocument != null
                                  ? selectedDocument!.path.split("/").last
                                  : "Joindre un document (optionnel)",
                              style: TextStyle(
                                color: selectedDocument != null
                                    ? Colors.black87
                                    : Colors.grey.shade500,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selectedDocument != null)
                            GestureDetector(
                              onTap: () =>
                                  setSheetState(() => selectedDocument = null),
                              child: Icon(Icons.close,
                                  color: Colors.grey.shade500, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text("Annuler",
                              style:
                              TextStyle(color: Colors.grey.shade700)),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            charge.document = selectedDocument;
                            BlocProvider.of<ChargesCubit>(context)
                                .validateCharge(charge);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text("Confirmer",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            "Aucune charge trouvée",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700),
          ),
          SizedBox(height: 8),
          Text(
            "Modifiez les filtres pour afficher les charges",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _listener(BuildContext context, ChargesState state) {
    if (state.actionStatus == AppStatus.success) {
      showToast("Charge validée avec succès", context, second: 2);
    } else if (state.actionStatus == AppStatus.error) {
      showToast(
        "",
        description: state.error ?? "Erreur",
        type: ToastificationType.error,
        context,
        second: 2,
      );
    } else if (state.deleteStatus == AppStatus.success) {
      showToast("Charge supprimée avec succès", context, second: 2);
    } else if (state.deleteStatus == AppStatus.error) {
      showToast(
        "",
        description: state.error ?? "L'annulation a échoué",
        type: ToastificationType.error,
        context,
        second: 2,
      );
    }
  }

  /// Annule une charge en demandant ce qui a ete recupere.
  ///
  /// Souvent tout, parfois rien, parfois une partie : c'est le montant
  /// saisi ici qui rentre en caisse, pas celui de la charge.
  void _annulerCharge(Charge charge) async {
    final resultat = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AnnulerChargeDialogue(charge: charge),
    );

    if (resultat != null && mounted) {
      BlocProvider.of<ChargesCubit>(context).annulerCharge(
        charge,
        montant: resultat["montant"] as double?,
        motif: resultat["motif"] as String?,
      );
    }
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) onPicked(picked);
  }

  void fetchData() {
    context.read<ChargesCubit>().fetchData();
  }
}

/// Ce qu'on demande avant d'annuler une charge.
///
/// Le montant rendu est proposé à la valeur de la charge : c'est le cas
/// courant, et le corriger reste possible.
class _AnnulerChargeDialogue extends StatefulWidget {
  final Charge charge;

  const _AnnulerChargeDialogue({required this.charge});

  @override
  State<_AnnulerChargeDialogue> createState() => _AnnulerChargeDialogueState();
}

class _AnnulerChargeDialogueState extends State<_AnnulerChargeDialogue> {
  late final TextEditingController _montant;
  final _motif = TextEditingController();
  String? _erreur;

  @override
  void initState() {
    super.initState();
    final regle = widget.charge.status == "payed";
    _montant = TextEditingController(
        text: regle ? (widget.charge.amount ?? 0).toStringAsFixed(2) : "0");
  }

  @override
  void dispose() {
    _montant.dispose();
    _motif.dispose();
    super.dispose();
  }

  void _valider() {
    final saisi = double.tryParse(_montant.text.trim().replaceAll(",", "."));
    final total = widget.charge.amount ?? 0;

    if (saisi == null || saisi < 0) {
      setState(() => _erreur = "Indiquez le montant rendu, ou 0.");
      return;
    }
    if (saisi > total + 0.001) {
      setState(() => _erreur =
          "Le montant rendu ne peut pas dépasser ${total.toStringAsFixed(2)} MAD.");
      return;
    }

    Navigator.of(context).pop({
      "montant": saisi,
      "motif": _motif.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text("Annuler la charge",
          style: TextStyle(fontSize: 17, color: Colors.black87)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "« ${widget.charge.nom ?? 'Charge'} » de "
              "${(widget.charge.amount ?? 0).toStringAsFixed(2)} MAD restera "
              "dans l'historique des charges annulées.",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
            SizedBox(height: 14),
            TextField(
              controller: _montant,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: "Montant rendu (MAD)",
                helperText: "Ce montant rentre dans votre caisse. 0 si rien "
                    "n'a été récupéré.",
                helperMaxLines: 2,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _motif,
              maxLines: 2,
              style: TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: "Motif (facultatif)",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (_erreur != null) ...[
              SizedBox(height: 10),
              Text(_erreur!,
                  style: TextStyle(fontSize: 12.5, color: Colors.red.shade700)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Retour"),
        ),
        ElevatedButton(
          onPressed: _valider,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
          ),
          child: Text("Annuler la charge"),
        ),
      ],
    );
  }
}
