import 'package:flutter/material.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/features/immobilier/contracts__list/cubit/contract_cubit.dart';
import 'package:immobilier/models/contract.dart';
import 'package:immobilier/models/media.dart';

import '../../../../routes.dart';
import 'package:immobilier/features/immobilier/contrat/ui/visionneuse_contrat.dart';

class ContractsList extends StatefulWidget {
  final int id;
  ContractsList({required this.id}) ;

  static Widget page(int id) => BlocProvider<ContractCubit>(
    create: (ctx) => ContractCubit(id)..fetchData(),
    child: ContractsList(id: id,),
  );

  @override
  State<ContractsList> createState() => _ContractsListState();
}

class _ContractsListState extends State<ContractsList> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Liste des contrats',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,

      ),
      body: BlocBuilder<ContractCubit, ContractState>(
        builder: (context, state) {
          return _buildContent(state);
        },
      ),
      floatingActionButton: !peut(AppPermission.createContract) ? null : FloatingActionButton(
          onPressed: _addContract,
        backgroundColor: AppColors.primaryColor,
        child: Icon(Icons.add,color: Colors.white,),
      ),
    );
  }

  Widget _buildContent(ContractState state) {
    if (state.fetchStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchStatus == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? "Error",
        action: AppStrings.tryAgain,
        actionCLick: _fetchData,
      );
    } else if (state.fetchStatus == AppStatus.success) {
      return state.contracts == null || state.contracts!.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: EdgeInsets.all(16),
              itemCount: state.contracts!.length,
              separatorBuilder: (context, index) => SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildContractCard(state.contracts![index]);
              },
            );
    }
    return SizedBox();
  }

  Widget _buildContractCard(Contract contract) {
    final isExpired =
        contract.expirationDate != null &&
        contract.expirationDate!.isBefore(DateTime.now());
    final daysUntilExpiration = contract.expirationDate?.difference(DateTime.now()).inDays;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired ? Colors.red.shade200 : Colors.grey.shade200,
          width: isExpired ? 2 : 1,
        ),
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
            // Contract ID and status
            Row(
              children: [
                Icon(Icons.description, size: 20, color: AppColors.primaryColor),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Contrat #${contract.id}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _buildStatusBadge(isExpired, daysUntilExpiration),
              ],
            ),

            SizedBox(height: 12),

            // Dates section
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: AppColors.primaryColor,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Date signature",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          contract.signedDate?.formattedDateFr ?? "N/A",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.blue.shade200),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event,
                                size: 14,
                                color: AppColors.primaryColor,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "Date expiration",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            contract.expirationDate?.formattedDateFr ?? "N/A",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isExpired
                                  ? Colors.red.shade700
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12),

            // Owner info
            if (contract.owner != null) ...[
              _buildInfoRow(
                Icons.person,
                "Propriétaire",
                contract.owner!.name ?? "N/A",
              ),
              SizedBox(height: 8),
            ],

            // Client info
            if (contract.client != null) ...[
              _buildInfoRow(
                Icons.account_circle,
                "Client",
                contract.client!.fullName,
              ),
              SizedBox(height: 8),
            ],

            // Property info
            if (contract.realestate != null) ...[
              _buildInfoRow(
                Icons.home,
                "Bien",
                contract.realestate!.title ?? "N/A",
              ),
              SizedBox(height: 8),
            ],

            // Documents count
            if (contract.documents != null &&
                contract.documents!.isNotEmpty) ...[
              _buildInfoRow(
                Icons.attach_file,
                "Documents",
                "${contract.documents!.length} fichier${contract.documents!.length > 1 ? 's' : ''}",
              ),
              SizedBox(height: 8),
            ],

            // Note
            if (contract.note != null && contract.note!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note, size: 14, color: Colors.grey.shade600),
                        SizedBox(width: 6),
                        Text(
                          "Note",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      contract.note!,
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
            ],

            // Action buttons
            Row(
              children: [
                /*Expanded(
                  child: OutlinedButton.icon(
                    onPressed:_viewDetailsClick,
                    icon: Icon(Icons.visibility, size: 16),
                    label: Text("Détails"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryColor,
                      side: BorderSide(color: AppColors.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),*/
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Download or view documents
                      _showDocuments(contract);
                    },
                    icon: Icon(Icons.file_copy, size: 16),
                    label: Text("Documents"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isExpired, int? daysUntilExpiration) {
    Color backgroundColor;
    Color textColor;
    String text;

    if (isExpired) {
      backgroundColor = Colors.red.shade100;
      textColor = Colors.red.shade700;
      text = "Expiré";
    } else if (daysUntilExpiration != null && daysUntilExpiration <= 30) {
      backgroundColor = Colors.orange.shade100;
      textColor = Colors.orange.shade700;
      text =
          "$daysUntilExpiration j restant${daysUntilExpiration > 1 ? 's' : ''}";
    } else {
      backgroundColor = Colors.green.shade100;
      textColor = Colors.green.shade700;
      text = "Actif";
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        SizedBox(width: 8),
        Text(
          "$label: ",
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            "Aucun contrat disponible",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Ajoutez votre premier contrat",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          SizedBox(height: 24),
          if (peut(AppPermission.createContract))
          ElevatedButton.icon(
            onPressed: _addContract,
            icon: Icon(Icons.add),
            label: Text("Ajouter un contrat"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDocuments(Contract contract) {
    if (contract.documents == null || contract.documents!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucun document disponible"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        "Documents du contrat",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8),

                ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: contract.documents!.length,
                  separatorBuilder: (context, index) => Divider(),
                  itemBuilder: (context, index) {
                    final doc = contract.documents![index];
                    return ListTile(
                      onTap: ()=>_onSelectDoc(doc),
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.insert_drive_file,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      title: Text(
                        "Document ${index + 1}",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text("ID: ${doc.id}"),

                    );
                  },
                ),

                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
  void _fetchData() {
    BlocProvider.of<ContractCubit>(context).fetchData();
  }



  void _onSelectDoc(Media doc) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final chemin =
          await BlocProvider.of<ContractCubit>(context).telechargerContrat(doc);
      if (!mounted) return;
      await VisionneuseContrat.ouvrir(context, chemin: chemin);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Le document n'a pas pu être ouvert."),
      ));
    }
  }

  void _addContract() async{
    await GoRouter.of(context).push(Routes.addContract.replaceFirst(":id", widget.id.toString()));
    _fetchData();
  }
}
