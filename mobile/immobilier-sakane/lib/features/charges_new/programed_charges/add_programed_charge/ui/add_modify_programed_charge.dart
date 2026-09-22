import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/form_field.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/core/validator/validator.dart';
import 'package:immobilier/models/programed_charge.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import '../cubit/add_modify_programed_charge_cubit.dart';

class AddModifyProgramedCharge extends StatefulWidget {
  final int? id;

  const AddModifyProgramedCharge({Key? key, this.id}) : super(key: key);

  static Widget page({int? id,int? realestate}) => BlocProvider<AddModifyProgramedChargeCubit>(
    create: (ctx) => AddModifyProgramedChargeCubit(id: id,realestate: realestate),
    child: AddModifyProgramedCharge(id: id),
  );

  @override
  State<AddModifyProgramedCharge> createState() => _AddModifyProgramedChargeState();
}

class _AddModifyProgramedChargeState extends State<AddModifyProgramedCharge> {
  final formKey = GlobalKey<FormState>();
  final nomController = TextEditingController();
  final descriptionController = TextEditingController();
  final amountController = TextEditingController();
  final dayController = TextEditingController();
  final monthController = TextEditingController();

  String selectedType = "week";
  String selectedDayName = "Monday";
  bool _filled = false;

  final daysInFrench = {
    "Monday": "Lundi",
    "Tuesday": "Mardi",
    "Wednesday": "Mercredi",
    "Thursday": "Jeudi",
    "Friday": "Vendredi",
    "Saturday": "Samedi",
    "Sunday": "Dimanche",
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.id != null ? "Modifier la charge" : "Nouvelle charge",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocConsumer<AddModifyProgramedChargeCubit, AddModifyProgramedChargeState>(
        listener: _listener,
        builder: (context, state) {
          // Fill controllers once when edit data is loaded
          if (state.fetchStatus == AppStatus.success &&
              state.programedCharge != null &&
              !_filled) {
            _fillForm(state.programedCharge!);
          }

          if (state.fetchStatus == AppStatus.loading) {
            return Center(child: MyLoadingIndicator());
          }

          if (state.fetchStatus == AppStatus.error) {
            return MyErrorWidget(
              error: state.error ?? "Erreur",
              action: AppStrings.tryAgain,
              actionCLick: () => BlocProvider.of<AddModifyProgramedChargeCubit>(context)
                  .fetchCharge(widget.id!),
            );
          }

          return _buildForm(state);
        },
      ),
    );
  }

  Widget _buildForm(AddModifyProgramedChargeState state) {
    final isLoading = state.actionStatus == AppStatus.loading;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Informations générales"),
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
            _buildSectionTitle("Programmation"),
            SizedBox(height: 12),

            // Type selector
            _buildTypeSelector(),
            SizedBox(height: 16),

            // Conditional fields
            if (selectedType == "week") _buildWeekField(),
            if (selectedType == "month") _buildMonthDayField(),
            if (selectedType == "year") _buildYearFields(),

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
                  widget.id != null ? "Modifier" : "Ajouter",
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

  Widget _buildTypeSelector() {
    final types = [
      {"value": "week", "label": "Hebdomadaire", "icon": Icons.view_week},
      {"value": "month", "label": "Mensuel", "icon": Icons.calendar_month},
      {"value": "year", "label": "Annuel", "icon": Icons.calendar_today},
    ];

    return Row(
      children: types.map((type) {
        final isSelected = selectedType == type["value"];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => selectedType = type["value"] as String),
            child: Container(
              margin: EdgeInsets.only(right: type["value"] != "year" ? 8 : 0),
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primaryColor : Colors.grey.shade300,
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  )
                ]
                    : [],
              ),
              child: Column(
                children: [
                  Icon(
                    type["icon"] as IconData,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    size: 22,
                  ),
                  SizedBox(height: 4),
                  Text(
                    type["label"] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeekField() {
    return DropdownButtonFormField<String>(
      value: selectedDayName,
      decoration: _dropdownDecoration("Jour de la semaine *"),
      items: daysInFrench.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (val) => setState(() => selectedDayName = val!),
    );
  }

  Widget _buildMonthDayField() {
    return MyFormField(
      label: "Jour du mois (1-30) *",
      hint: "Ex: 15",
      labelColor: Colors.black,
      borderColor: Colors.black,
      hintColor: Colors.black54,
      activeBorderColor: Colors.black,
      controller: dayController,
      inputType: TextInputType.number,
      validator: Validator().required().number().make(),
    );
  }

  Widget _buildYearFields() {
    return Column(
      children: [
        MyFormField(
          label: "Mois (1-12) *",
          hint: "Ex: 6",
          labelColor: Colors.black,
          borderColor: Colors.black,
          hintColor: Colors.black54,
          activeBorderColor: Colors.black,
          controller: monthController,
          inputType: TextInputType.number,
          validator: Validator().required().number().make(),
        ),
        SizedBox(height: 12),
        MyFormField(
          label: "Jour (1-30) *",
          hint: "Ex: 1",
          labelColor: Colors.black,
          borderColor: Colors.black,
          hintColor: Colors.black54,
          activeBorderColor: Colors.black,
          controller: dayController,
          inputType: TextInputType.number,
          validator: Validator().required().number().make(),
        ),
      ],
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.black),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.black),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.black, width: 2),
      ),
    );
  }

  void _fillForm(ProgramedCharge charge) {
    _filled = true;
    nomController.text = charge.nom ?? "";
    descriptionController.text = charge.description ?? "";
    amountController.text = charge.amount?.toString() ?? "";
    selectedType = charge.type ?? "week";
    selectedDayName = charge.dayName ?? "Monday";
    dayController.text = charge.day?.toString() ?? "";
    monthController.text = charge.month?.toString() ?? "";
  }

  void _submit() {
    if (formKey.currentState!.validate()) {
      final charge = ProgramedCharge(
        nom: nomController.text.trim(),
        description: descriptionController.text.trim(),
        amount: double.parse(amountController.text.trim()),
        type: selectedType,
        dayName: selectedType == "week" ? selectedDayName : null,
        day: selectedType != "week" ? int.tryParse(dayController.text.trim()) : null,
        month: selectedType == "year" ? int.tryParse(monthController.text.trim()) : null,
      );
      BlocProvider.of<AddModifyProgramedChargeCubit>(context).submit(charge);
    }
  }

  void _listener(BuildContext context, AddModifyProgramedChargeState state) {
    if (state.actionStatus == AppStatus.success) {
      showToast(
        widget.id != null
            ? "Charge modifiée avec succès"
            : "Charge ajoutée avec succès",
        context,
        second: 2,
      );
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
    dayController.dispose();
    monthController.dispose();
    super.dispose();
  }
}