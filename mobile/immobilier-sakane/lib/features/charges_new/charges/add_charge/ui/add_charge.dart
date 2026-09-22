import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:immobilier/components/form_field.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/core/validator/validator.dart';
import 'package:immobilier/models/charge.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import '../cubit/add_charge_cubit.dart';

class AddChargePage extends StatefulWidget {
  const AddChargePage({Key? key}) : super(key: key);

  static Widget page({int? realestate}) => BlocProvider<AddChargeCubit>(
    create: (ctx) => AddChargeCubit(realestate: realestate),
    child: const AddChargePage(),
  );

  @override
  State<AddChargePage> createState() => _AddChargePageState();
}

class _AddChargePageState extends State<AddChargePage> {
  final formKey = GlobalKey<FormState>();
  final nomController = TextEditingController();
  final descriptionController = TextEditingController();
  final amountController = TextEditingController();
  File? selectedDocument;

  /// Statut de la charge : payee (par defaut) ou en attente de paiement
  bool _estPayee = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Nouvelle Charge",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocConsumer<AddChargeCubit, AddChargeState>(
        listener: _listener,
        builder: (context, state) {
          final isLoading = state.actionStatus == AppStatus.loading;
          return SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Informations"),
                  SizedBox(height: 12),
                  MyFormField(
                    label: "Nom *",
                    hint: "Entrez le nom",
                    labelColor: Colors.black,
                    borderColor: Colors.black,
                    hintColor: Colors.black54,
                    activeBorderColor: Colors.black,
                    controller: nomController,
                    validator: Validator().required().make(),
                  ),
                  SizedBox(height: 12),
                  MyFormField(
                    label: "Description *",
                    hint: "Entrez la description",
                    labelColor: Colors.black,
                    borderColor: Colors.black,
                    hintColor: Colors.black54,
                    activeBorderColor: Colors.black,
                    controller: descriptionController,
                    validator: Validator().required().make(),
                  ),
                  SizedBox(height: 12),
                  MyFormField(
                    label: "Montant *",
                    hint: "Entrez le montant",
                    labelColor: Colors.black,
                    borderColor: Colors.black,
                    hintColor: Colors.black54,
                    activeBorderColor: Colors.black,
                    controller: amountController,
                    inputType: TextInputType.numberWithOptions(decimal: true),
                    validator: Validator().required().number().make(),
                  ),
                  SizedBox(height: 24),
                  _buildSectionTitle("Cette charge concerne"),
                  SizedBox(height: 12),
                  _buildCibleSelector(state),
                  SizedBox(height: 24),
                  _buildSectionTitle("Document"),
                  SizedBox(height: 12),
                  _buildStatutSelector(),
                  SizedBox(height: 20),
                  _buildDocumentPicker(),
                  SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        "Ajouter",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Sur l'agence, ou sur un appartement.
  ///
  /// Une charge d'agence ne se rattache a aucun bien : c'est le cas des
  /// frais generaux. Une charge d'appartement suit le bien choisi.
  Widget _buildCibleSelector(AddChargeState state) {
    final surBien = state.realestate != null;
    final cubit = context.read<AddChargeCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _choixCible(
                titre: "L'agence",
                sousTitre: "Frais généraux",
                icone: Icons.storefront_outlined,
                choisi: !surBien,
                onTap: () => cubit.choisirBien(null),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _choixCible(
                titre: "Un appartement",
                sousTitre: "Charge d'un bien",
                icone: Icons.apartment_outlined,
                choisi: surBien,
                onTap: () {
                  if (state.biens.isEmpty) {
                    showToast("La liste des appartements n'est pas encore "
                        "chargée.", context, type: ToastificationType.warning);
                    return;
                  }
                  cubit.choisirBien(state.biens.first.id);
                },
              ),
            ),
          ],
        ),
        if (surBien) ...[
          SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: state.biens.any((b) => b.id == state.realestate)
                ? state.realestate
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: "Appartement",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              isDense: true,
            ),
            items: state.biens
                .where((b) => b.id != null)
                .map((b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(b.title ?? "Bien n° ${b.id}",
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => cubit.choisirBien(v),
          ),
        ],
      ],
    );
  }

  /// Une des deux cibles possibles, presentee comme une carte.
  Widget _choixCible({
    required String titre,
    required String sousTitre,
    required IconData icone,
    required bool choisi,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: choisi ? AppColors.primaryColor.withValues(alpha: 0.08) : Colors.white,
          border: Border.all(
            color: choisi ? AppColors.primaryColor : Colors.grey.shade400,
            width: choisi ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icone,
                size: 20,
                color: choisi ? AppColors.primaryColor : Colors.grey.shade600),
            SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: choisi ? AppColors.primaryColor : Colors.black87,
                      )),
                  Text(sousTitre,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryColor,
      ),
    );
  }

  Widget _buildDocumentPicker() {
    return GestureDetector(
      onTap: _pickDocument,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedDocument != null
                ? Colors.green.shade400
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selectedDocument != null
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                selectedDocument != null
                    ? Icons.check_circle
                    : Icons.upload_file,
                color: selectedDocument != null
                    ? Colors.green.shade600
                    : AppColors.primaryColor,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedDocument != null ? "Document joint" : "Joindre un document",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    selectedDocument != null
                        ? selectedDocument!.path.split("/").last
                        : "Optionnel • PDF, JPG, PNG",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (selectedDocument != null)
              GestureDetector(
                onTap: () => setState(() => selectedDocument = null),
                child: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  /// Propose de photographier le justificatif ou de le choisir dans la galerie.
  Future<void> _pickDocument() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Justificatif de la charge",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined,
                  color: AppColors.primaryColor),
              title: const Text("Prendre une photo"),
              subtitle: const Text("Photographier le reçu ou la facture"),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: AppColors.primaryColor),
              title: const Text("Choisir un fichier"),
              subtitle: const Text("Depuis la galerie du téléphone"),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() => selectedDocument = File(picked.path));
    }
  }

  /// Choix du statut : payee ou en attente de paiement.
  Widget _buildStatutSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Statut du paiement",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _optionStatut(
                libelle: "Payée",
                icone: Icons.check_circle_outline,
                couleur: Colors.green.shade600,
                actif: _estPayee,
                onTap: () => setState(() => _estPayee = true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _optionStatut(
                libelle: "Non payée",
                icone: Icons.schedule,
                couleur: Colors.orange.shade700,
                actif: !_estPayee,
                onTap: () => setState(() => _estPayee = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _estPayee
              ? "La dépense est enregistrée immédiatement en comptabilité."
              : "La charge devra être validée pour être comptabilisée.",
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _optionStatut({
    required String libelle,
    required IconData icone,
    required Color couleur,
    required bool actif,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
        decoration: BoxDecoration(
          color: actif ? couleur.withValues(alpha: 0.10) : Colors.white,
          border: Border.all(
            color: actif ? couleur : Colors.grey.shade300,
            width: actif ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 19, color: actif ? couleur : Colors.grey.shade500),
            const SizedBox(width: 7),
            Text(
              libelle,
              style: TextStyle(
                fontWeight: actif ? FontWeight.bold : FontWeight.normal,
                color: actif ? couleur : Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;

    final charge = Charge(
      nom: nomController.text.trim(),
      description: descriptionController.text.trim(),
      amount: double.parse(amountController.text.trim()),
      status: _estPayee ? "payed" : "pending",
    )..document = selectedDocument;

    // Seule une charge reglee sort des especes : une charge en attente
    // ne touche pas encore a la caisse.
    if (_estPayee && (charge.amount ?? 0) > 0) {
      final prete = await garantirCaisseOuverte(
        context,
        motif: "cette charge",
        sortie: charge.amount ?? 0,
      );
      if (!prete || !mounted) return;
    }

    if (!mounted) return;
    BlocProvider.of<AddChargeCubit>(context).addCharge(charge);
  }

  void _listener(BuildContext context, AddChargeState state) {
    if (state.actionStatus == AppStatus.success) {
      showToast("Charge ajoutée avec succès", context, second: 2);
      Navigator.pop(context, true);
    } else if (state.actionStatus == AppStatus.error) {
      showToast(
        "",
        description: state.error ?? "Erreur",
        type: ToastificationType.error,
        context,
        second: 2,
      );
    }
  }

  @override
  void dispose() {
    nomController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    super.dispose();
  }
}