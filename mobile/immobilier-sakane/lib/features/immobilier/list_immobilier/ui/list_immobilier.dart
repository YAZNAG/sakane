import 'package:immobilier/components/entete_defilant.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/components/tableaux_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/empty_widget.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/immobilier/list_immobilier/bloc/realestate_cubit.dart';
import 'package:immobilier/features/immobilier/list_immobilier/ui/components/realestate_widget.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/routes.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/features/immobilier/list_immobilier/ui/components/filtres_biens.dart';
import 'package:immobilier/components/bandeau_synchro.dart';
import 'package:immobilier/core/utils/rafraichissement_auto.dart';
import 'package:immobilier/features/biens_desactives/outils_desactivation.dart';






class ImmobilierPage extends StatefulWidget {
  /// Filtres appliques a l'ouverture, quand l'ecran est atteint depuis
  /// la navigation par type puis par secteur.
  final String? typeInitial;
  final int? secteurInitial;
  final bool sansSecteur;

  ImmobilierPage({
    Key? key,
    this.typeInitial,
    this.secteurInitial,
    this.sansSecteur = false,
  }) : super(key: key);

  static Widget page({
    String? typeInitial,
    int? secteurInitial,
    bool sansSecteur = false,
  }) =>
      BlocProvider<RealestateCubit>(
        create: (ctx) => RealestateCubit(),
        child: ImmobilierPage(
          typeInitial: typeInitial,
          secteurInitial: secteurInitial,
          sansSecteur: sansSecteur,
        ),
      );

  @override
  State<ImmobilierPage> createState() => _ImmobilierPageState();
}

class _ImmobilierPageState extends State<ImmobilierPage>
    with RafraichissementAuto<ImmobilierPage> {

  TableauExportable? _tableauExport() {
    final tous = context.read<RealestateCubit>().state.realestates;
    if (tous == null) return null;
    return tableauBiens('Biens immobiliers', _criteres.appliquer(tous).toList());
  }

  @override
  void rafraichir() => fetchData();

  late final CriteresBiens _criteres = CriteresBiens(
    type: widget.typeInitial ?? 'tous',
    secteurId: widget.secteurInitial,
    sansSecteur: widget.sansSecteur,
  );

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    fetchData();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Les bien immobilier',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        foregroundColor:Colors.white ,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [BoutonExport(tableau: _tableauExport)],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: BlocConsumer<RealestateCubit, RealestateState>(
          listener: (context, state) {
            if (state.deleteStatus == AppStatus.success) {
              showToast("Bien supprimé avec succès", context, second: 2);
            } else if (state.deleteStatus == AppStatus.error) {
              showToast("", description: state.error ?? "Erreur de suppression",
                  type: ToastificationType.error, context, second: 2);
            }
          },
          builder: (ctx, state) {
            return _buildContent(state);
          },
        ),
      ),
      floatingActionButton: !Dependencies.get<Manager>().can(AppPermission.createProperty) ? null : FloatingActionButton(
        onPressed: addRealestate,
        child: Icon(Icons.add,color: Colors.white,),
        backgroundColor: AppColors.primaryColor,
      ),
    );
  }

  Widget _buildContent(RealestateState state) {
    if(state.fetchStatus==AppStatus.loading){
      return Center(child: MyLoadingIndicator(),);
    }else if(state.fetchStatus==AppStatus.error){
      return MyErrorWidget(error: state.error??"Error", action: AppStrings.tryAgain,actionCLick: fetchData,);
    }else if(state.fetchStatus==AppStatus.success){

      if(state.realestates?.isEmpty??true){
        return _buildEmptyState();
      }

      final canDelete = Dependencies.get<Manager>().can(AppPermission.deleteProperty);
      final tous = state.realestates!;
      final filtres = _criteres.appliquer(tous);

      return PageAEnTeteDefilant(
        entete: [
          const BandeauSynchro(),
          FiltresBiens(
            criteres: _criteres,
            tousLesBiens: tous,
            nombreAffiche: filtres.length,
            onChange: () => setState(() {}),
          ),
        ],
        corps: filtres.isEmpty
                ? _buildAucunResultat()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: filtres.length,
                    itemBuilder: (context, index) {
                      final realestate = filtres.elementAt(index);
                      return RealestateWidget(
                        realestate: realestate,
                        onClick: onRealstateClick,
                        // Appui long : « Désactiver le bien »
                        onLondClick: peutDesactiverBien() ? _actionsAppuiLong : null,
                        onDelete: canDelete ? _deleteRealestate : null,
                      );
                    },
                  ),
      );
    }
    return SizedBox();
  }


  /// Aucun bien ne correspond aux criteres choisis.
  Widget _buildAucunResultat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            "Aucun bien ne correspond à votre recherche",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => setState(() {
              _criteres.reinitialiser();
              _criteres.recherche = '';
              _criteres.etat = 'tous';
            }),
            icon: const Icon(Icons.refresh, size: 17),
            label: const Text("Effacer les filtres"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            "Aucun immobiliers disponible",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }




  void fetchData() {
    BlocProvider.of<RealestateCubit>(context).fetchData();
  }

  void addRealestate() async{
    await GoRouter.of(context).push(Routes.addImmobilier);
    fetchData();
  }

  void onRealstateClick(Realestate r) async {
    final modifie = await GoRouter.of(context).push(Routes.homeImmobilier.replaceAll(":id",r.id.toString()));
    if (modifie == true && mounted) fetchData();
  }

  Future<void> _actionsAppuiLong(Realestate r) async {
    if (r.id == null) return;
    final desactive = await actionsBienParAppuiLong(context, bienId: r.id!, titre: r.title);
    if (desactive && mounted) fetchData();
  }

  void _deleteRealestate(Realestate realestate) async {
    final confirmed = await showDialogueQuestion(
        context, "Voulez-vous vraiment supprimer ce bien ?");
    if (confirmed == true && mounted) {
      BlocProvider.of<RealestateCubit>(context).deleteRealestate(realestate);
    }
  }
}