import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/form_field.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/components/validation_error.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/core/utils/show_error_dialogue.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/core/validator/validator.dart';
import 'package:immobilier/features/immobilier/charges/cubit/charges_cubit.dart';
import 'package:immobilier/models/charge.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/core/constants/app_colors.dart';
class ChargesScreen extends StatefulWidget {
  final int? propertyId;

  const ChargesScreen({Key? key, required this.propertyId}) : super(key: key);

  static Widget page({int? id}) => BlocProvider<ChargesCubit>(
    create: (ctx) => ChargesCubit(id)..fetchData(),
    child: ChargesScreen(propertyId: id),
  );

  @override
  State<ChargesScreen> createState() => _ChargesScreenState();
}

class _ChargesScreenState extends State<ChargesScreen> {
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
      ),
      floatingActionButton: !Dependencies.get<Manager>().can(AppPermission.createCharge) ? null : FloatingActionButton(
        onPressed: () => _showAddChargeDialog(),
        backgroundColor: AppColors.primaryColor,
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: BlocConsumer<ChargesCubit, ChargesState>(
        listener: _listener,
        builder: (context, state) {
          return _buildContent(state);
        },
      ),
    );
  }

  Widget _buildContent(ChargesState state) {
    if (state.fetchStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchStatus == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? "Error",
        action: AppStrings.tryAgain,
        actionCLick: () => BlocProvider.of<ChargesCubit>(context).fetchData(),
      );
    } else if (state.fetchStatus == AppStatus.success) {
      return Column(
        children: [
          // Date filter section
          _buildDateFilterSection(state),

          // Total section
          if (state.charges != null && state.charges!.isNotEmpty)
            _buildTotalSection(state),

          // Charges list
          Expanded(
            child: state.charges == null || state.charges!.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
              padding: EdgeInsets.all(16),
              itemCount: state.charges!.length,
              separatorBuilder: (context, index) => SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildChargeCard(state.charges![index]);
              },
            ),
          ),
        ],
      );
    }
    return SizedBox();
  }

  Widget _buildDateFilterSection(ChargesState state) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: MyFormField(
              label: "",
              hint: "Date début",
              readOnly: true,
              borderColor: Colors.black,
              activeBorderColor: Colors.black,
              labelColor: Colors.black,
              onTap: () => _pickDate(
                initialDate: state.from!,
                onPicked: (dt) {
                  BlocProvider.of<ChargesCubit>(context).pickDate("from", dt);
                },
              ),
              controller: TextEditingController()..text = state.from!.formattedDateFr,
              //suffix: Icon(Icons.calendar_today, size: 20, color: Colors.grey),
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
              onTap: () => _pickDate(
                initialDate: state.to!,
                onPicked: (dt) {
                  BlocProvider.of<ChargesCubit>(context).pickDate("to", dt);
                },
              ),
              controller: TextEditingController()..text = state.to!.formattedDateFr,
              //suffix: Icon(Icons.calendar_today, size: 20, color: Colors.grey),
            ),
          ),
          SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () => BlocProvider.of<ChargesCubit>(context).fetchData(),
              icon: Icon(Icons.search, color: Colors.white),
              tooltip: "Rechercher",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection(ChargesState state) {
    final total = state.charges!.fold<double>(
      0.0,
          (sum, charge) => sum + (charge.amount ?? 0.0),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryColor, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Total des charges",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "${total.toStringAsFixed(2)} MAD",
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "${state.charges!.length} charge${state.charges!.length > 1 ? 's' : ''}",
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargeCard(Charge charge) {
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
                  child: Icon(
                    Icons.receipt_long,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Charge",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      if (charge.createdAt != null)
                        Text(
                          charge.createdAt!.formattedDateFr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  "${charge.amount?.toStringAsFixed(2) ?? '0.00'} MAD",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                if (Dependencies.get<Manager>().can(AppPermission.deleteCharge))
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 22),
                    tooltip: 'Supprimer',
                    onPressed: () => _deleteCharge(charge),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCharge(Charge charge) async {
    final confirmed = await showDialogueQuestion(
        context, "Voulez-vous vraiment supprimer cette charge ?");
    if (confirmed == true && mounted) {
      BlocProvider.of<ChargesCubit>(context).deleteCharge(charge);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            "Aucune charge enregistrée",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Ajoutez votre première charge",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),

        ],
      ),
    );
  }

  void _showAddChargeDialog() {
    final formKey = GlobalKey<FormState>();
    final noteController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_circle_outline, color: AppColors.primaryColor),
              SizedBox(width: 8),
              Text(
                "Ajouter une charge",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MyFormField(
                    label: "Description *",
                    hint: "Entrez la description",
                    labelColor: Colors.black,
                    borderColor: Colors.black,
                    hintColor: Colors.black54,
                    activeBorderColor: Colors.black,
                    controller: noteController,
                    //validator: Validator().required().make(),
                  ),
                  SizedBox(height: 16),
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
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Annuler",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final charge = Charge(

                    amount: double.parse(amountController.text.trim()),
                    realEstate: Realestate(id: widget.propertyId),
                  );

                  BlocProvider.of<ChargesCubit>(context).addCharge(charge);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
              ),
              child: Text(
                "Ajouter",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
          backgroundColor: Colors.white,

        );
      },
    );
  }

  void _listener(BuildContext context, ChargesState state) {
    if (state.addStatus == AppStatus.success) {
      showToast("Charge ajoutée avec succès", context, second: 2);
    } else if (state.addStatus == AppStatus.error) {
      if (state.errors != null) {
        showDialogueError(context, state.errors!);
      } else {
        showToast("", description: state.error ?? "Error",
            type: ToastificationType.error, context, second: 2);
      }
    } else if (state.deleteStatus == AppStatus.success) {
      showToast("Charge supprimée avec succès", context, second: 2);
    } else if (state.deleteStatus == AppStatus.error) {
      showToast("", description: state.error ?? "Erreur de suppression",
          type: ToastificationType.error, context, second: 2);
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
}

