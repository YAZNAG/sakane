import 'package:immobilier/components/bouton_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/programed_charge.dart';
import 'package:toastification/toastification.dart';

import '../../../../../routes.dart';
import '../cubit/programed_charges_cubit.dart';
import 'package:immobilier/core/constants/app_colors.dart';



class ProgramedChargesPage extends StatefulWidget {
  final int? propertyId;

  ProgramedChargesPage({this.propertyId}) ;

  static Widget page({int? realestate}) => BlocProvider<ProgramedChargesCubit>(
    create: (ctx) => ProgramedChargesCubit(realestate: realestate)..fetchData(),
    child:  ProgramedChargesPage(propertyId: realestate,),
  );

  @override
  State<ProgramedChargesPage> createState() => _ProgramedChargesPageState();
}

class _ProgramedChargesPageState extends State<ProgramedChargesPage> {

  /// Droit « Supprimer une charge programmée » (l'administrateur l'a).
  bool get _peutSupprimer =>
      Dependencies.get<Manager>().can(AppPermission.deleteProgramedCharge);

  TableauExportable? _tableauExport() {
    final liste = context.read<ProgramedChargesCubit>().state.programedCharges;
    if (liste == null) return null;
    double total = 0;
    final lignes = liste.map((c) {
      total += c.amount ?? 0;
      return [
        c.nom ?? '',
        c.description ?? '',
        c.realestate?.title ?? 'Agence',
        c.type ?? '',
        [
          if (c.day != null) 'jour ${c.day}',
          if (c.month != null) 'mois ${c.month}',
          if ((c.dayName ?? '').isNotEmpty) c.dayName!,
        ].join(' • '),
        montantExport(c.amount),
      ];
    }).toList();
    return TableauExportable(
      titre: 'Charges programmées',
      colonnes: const ['Nom', 'Description', 'Bien', 'Fréquence', 'Échéance', 'Montant'],
      lignes: lignes,
      totaux: ['TOTAL', '', '', '', '', montantExport(total)],
    );
  }



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
          'Charges Programmées',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [BoutonExport(tableau: _tableauExport)],
      ),
      floatingActionButton: !Dependencies.get<Manager>().can(AppPermission.createProgramedCharge) ? null : FloatingActionButton(
        onPressed: () async{
          final route=Routes.createProgramedCharges+(widget.propertyId!=null?"?realestate=${widget.propertyId}":"");
          await GoRouter.of(context).push(route);
          fetchData();
        },
        backgroundColor: AppColors.primaryColor,
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: BlocConsumer<ProgramedChargesCubit, ProgramedChargesState>(
        listener: _listener,
        builder: (context, state) => _buildContent(state),
      ),
    );
  }

  Widget _buildContent(ProgramedChargesState state) {
    if (state.fetchStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchStatus == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? "Erreur",
        action: AppStrings.tryAgain,
        actionCLick: () =>
            BlocProvider.of<ProgramedChargesCubit>(context).fetchData(),
      );
    } else if (state.fetchStatus == AppStatus.success) {
      if (state.programedCharges == null || state.programedCharges!.isEmpty) {
        return _buildEmptyState();
      }
      return ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: state.programedCharges!.length,
        separatorBuilder: (_, __) => SizedBox(height: 12),
        itemBuilder: (_, index) =>
            _buildChargeCard(state.programedCharges![index]),
      );
    }
    return SizedBox();
  }

  Widget _buildChargeCard(ProgramedCharge charge) {
    final typeInfo = _getTypeInfo(charge);

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
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.schedule, color: AppColors.primaryColor, size: 24),
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
                  SizedBox(height: 4),
                  Text(
                    charge.description ?? "-",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeInfo["color"] as Color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      typeInfo["label"] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${charge.amount?.toStringAsFixed(2) ?? '0.00'} MAD",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
                if (_peutSupprimer)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                    tooltip: 'Supprimer',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    onPressed: () => _deleteProgramedCharge(charge),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getTypeInfo(ProgramedCharge charge) {
    switch (charge.type) {
      case "week":
        return {
          "label": "Hebdo • ${daysInFrench[charge.dayName] ?? ''}",
          "color": Colors.green.shade600,
        };
      case "month":
        return {
          "label": "Mensuel • Jour ${charge.day ?? ''}",
          "color": Colors.orange.shade600,
        };
      case "year":
        return {
          "label": "Annuel • Mois ${charge.month} / Jour ${charge.day}",
          "color": Colors.purple.shade600,
        };
      default:
        return {"label": "-", "color": Colors.grey};
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 80, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            "Aucune charge programmée",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Ajoutez votre première charge programmée",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }



  void _listener(BuildContext context, ProgramedChargesState state) {
    if (state.deleteStatus == AppStatus.success) {
      showToast("Charge supprimée avec succès", context, second: 2);
    } else if (state.deleteStatus == AppStatus.error) {
      showToast(
        "",
        description: state.error ?? "Erreur de suppression",
        type: ToastificationType.error,
        context,
        second: 2,
      );
    }
  }

  void _deleteProgramedCharge(ProgramedCharge charge) async {
    final confirmed = await showDialogueQuestion(
        context, "Voulez-vous vraiment supprimer cette charge programmée ?");
    if (confirmed == true && mounted) {
      BlocProvider.of<ProgramedChargesCubit>(context).deleteProgramedCharge(charge);
    }
  }

  void fetchData() {
    context.read<ProgramedChargesCubit>().fetchData();
  }
}