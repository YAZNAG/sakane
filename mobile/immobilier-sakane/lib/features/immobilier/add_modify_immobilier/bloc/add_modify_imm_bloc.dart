import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';

import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/exceptions/validation_exception.dart';
import 'package:immobilier/models/address.dart';
import 'package:immobilier/models/city.dart';
import 'package:immobilier/models/dossier.dart';
import 'package:immobilier/models/feature.dart';
import 'package:immobilier/models/owner.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/models/region.dart';
import 'package:immobilier/models/type_transaction.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:meta/meta.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';
import '../../../../models/category.dart';
import '../../../../models/etat.dart';
import 'package:immobilier/models/secteur.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/brouillons.dart';

part 'add_modify_imm_event.dart';
part 'add_modify_imm_state.dart';

class AddModifyImmBloc extends Bloc<AddModifyImmEvent, AddModifyImmState> {
  /// Nouveau bien : famille (rent-short, rent-long, selle) et dossier preselectionnes.
  final String? typeInitial;
  final int? dossierInitial;

  /// Brouillon repris : la saisie est restauree une fois les listes chargees.
  final BrouillonBien? brouillon;

  /// Rend la saisie de l'etape affichee (sans validation), pour le brouillon.
  /// Chaque etape s'y inscrit a son affichage.
  Realestate Function()? instantaneEtape;

  AddModifyImmBloc({int? id, this.typeInitial, this.dossierInitial, this.brouillon})
      : super(AddModifyImmState(realestateId: id)) {
   on<FetchData>(_fetchData);

   on<UpdateRealestate>((event,emit){
     print("bloc:${event.realestate}");
     emit(state.copyWith(realestate: event.realestate));
   });
   on<SelectRegion>(_selectRegion);
   on<AddRealestate>(_addRealestate);
   on<AddOwner>(_addOwner);
   on<AddSecteur>(_addSecteur);
   on<AddDossier>(_addDossier);
   on<UpdateImmobilier>(_updateImmobilier);
  }

  FutureOr<void> _fetchData(FetchData event, Emitter<AddModifyImmState> emit) async{
    try{
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      var result=await Future.wait([
        repository.fetchEtats(),
        repository.fetchCategories(),
        repository.fetchTransactionTypes(),
        repository.fetchRegions(),
        repository.fetchFeatures(),
        repository.fetchOwners(),
        repository.fetchSecteurs(),
        repository.fetchDossiers(),
        if(state.realestateId!=null)
          repository.fetchRealesate(state.realestateId!)
      ]);
      final owners = result[5] as List<Owner>;
      final nouveau = state.realestateId == null
          ? _nouveauBien(
              categories: result[1] as List<Category>,
              etats: result[0] as List<Etat>,
              types: result[2] as List<TypeTransaction>,
              regions: result[3] as List<Region>,
              features: result[4] as List<Feature>,
              owners: owners,
              secteurs: result[6] as List<Secteur>,
              dossiers: result[7] as List<Dossier>,
            )
          : null;
      // Un proprietaire absent de la liste (cree avec un mandat) doit y figurer.
      final owner = nouveau?.owner;
      final listeOwners = owner != null && !owners.contains(owner) ? [...owners, owner] : owners;
      emit(state.copyWith(
        fetchStatus: AppStatus.success,
        etats: result[0] as List<Etat>,
        categories: result[1] as List<Category>,
        typeTransaction: result[2] as List<TypeTransaction>,
        regions: result[3] as List<Region>,
        features: result[4] as List<Feature>,
        owners: listeOwners,
        secteurs: result[6] as List<Secteur>,
        dossiers: result[7] as List<Dossier>,
        realestate: state.realestateId!=null
            ?result[8] as Realestate
            :nouveau
      ));
      final region = state.realestate?.address?.region;
      // Modification ou brouillon : les villes de la region se rechargent.
      if(region!=null){
        add(SelectRegion(region,true));
      }
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch(ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error,error: AppStrings.authorizationError));
    }catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error,error: "Error"));
      rethrow;
    }
  }

  /// La saisie de depart d'un nouveau bien : le brouillon, ou la famille
  /// et le dossier d'ou l'ajout a ete lance.
  Realestate? _nouveauBien({
    List<Category>? categories,
    List<Etat>? etats,
    List<TypeTransaction>? types,
    List<Region>? regions,
    List<Feature>? features,
    List<Owner>? owners,
    List<Secteur>? secteurs,
    List<Dossier>? dossiers,
  }) {
    if (brouillon != null) {
      return Brouillons.versBien(
        brouillon!,
        categories: categories,
        etats: etats,
        types: types,
        regions: regions,
        owners: owners,
        secteurs: secteurs,
        dossiers: dossiers,
        features: features,
      );
    }
    if (typeInitial == null && dossierInitial == null) return null;
    TypeTransaction? type;
    for (final t in types ?? const <TypeTransaction>[]) {
      if (t.value == typeInitial) type = t;
    }
    Dossier? dossier;
    for (final d in dossiers ?? const <Dossier>[]) {
      if (dossierInitial != null && d.id == dossierInitial) dossier = d;
    }
    return Realestate(typeTransaction: type, dossier: dossier);
  }

  FutureOr<void> _selectRegion(SelectRegion event, Emitter<AddModifyImmState> emit)async {
    try{
      Realestate realestate=state.realestate??Realestate();
      Address address=realestate.address??Address();
      Address na=address.copyWith(region: event.region);
      emit(state.copyWith(realestate:realestate.copyWith(address: na)));
      Repository repository=Dependencies.get<Repository>();
      List<City> cities=await repository.fetchCities(regionId: event.region.id!);
      if(!event.keepOld){
        realestate=realestate.copyWith(address: na.copyWith(city: cities.elementAt(0)));
      }

      emit(state.copyWith(cities: cities,realestate: realestate));
    } catch(ex){
      print(ex.toString());
    }
  }

  FutureOr<void> _addRealestate(AddRealestate event, Emitter<AddModifyImmState> emit)async {
    try{
      emit(state.copyWith(addModifyStatus:AppStatus.loading ));
      Repository repository=Dependencies.get<Repository>();
      Realestate realestate=await repository.addRealestate(state.realestate!);
      // Le bien cree (avec son id) : l'ecran propose la suite selon son type.
      realestate.typeTransaction ??= state.realestate?.typeTransaction;
      emit(state.copyWith(addModifyStatus:AppStatus.success, realestate: realestate));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(addModifyStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch(ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(addModifyStatus: AppStatus.error,error: AppStrings.authorizationError));
    }on ValidatorException catch(ex){
     emit(state.copyWith(addModifyStatus: AppStatus.error,errors: ex.errors));
    }catch(ex){
      emit(state.copyWith(addModifyStatus: AppStatus.error,error: "Error"));
    }
  }

  FutureOr<void> _updateImmobilier(UpdateImmobilier event, Emitter<AddModifyImmState> emit)async {
    try{
      emit(state.copyWith(addModifyStatus:AppStatus.loading ));
      Repository repository=Dependencies.get<Repository>();
      Realestate realestate=await repository.updateRealestate(state.realestate!);
      emit(state.copyWith(addModifyStatus:AppStatus.success,realestate: realestate));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(addModifyStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch(ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(addModifyStatus: AppStatus.error,error: AppStrings.authorizationError));
    }catch(ex){
      emit(state.copyWith(addModifyStatus: AppStatus.error,error: "Error"));
    }
  }

  /// Cree un secteur cote serveur puis l'affecte au bien en cours.
  /// Cree un dossier et l'attribue aussitot au bien en cours.
  ///
  /// Le serveur renvoie le dossier existant si le nom est deja pris :
  /// deux biens ranges sous le meme nom se retrouvent au meme endroit.
  FutureOr<void> _addDossier(AddDossier event, Emitter<AddModifyImmState> emit) async {
    try {
      Repository repository = Dependencies.get<Repository>();
      Dossier dossier = await repository.creerDossier(event.nom);

      List<Dossier> liste = [...(state.dossiers ?? [])];
      if (!liste.any((d) => d.id == dossier.id)) {
        liste = [...liste, dossier]
          ..sort((a, b) => (a.nom ?? '').compareTo(b.nom ?? ''));
      }

      Realestate realestate = state.realestate ?? Realestate();
      emit(state.copyWith(
        dossiers: liste,
        realestate: realestate.copyWith(dossier: dossier),
      ));
    } catch (ex) {
      emit(state.copyWith(error: "Impossible de créer le dossier"));
    }
  }

  FutureOr<void> _addSecteur(AddSecteur event, Emitter<AddModifyImmState> emit) async {
    try {
      Repository repository = Dependencies.get<Repository>();
      Secteur secteur = await repository.addSecteur(
        event.nom,
        cityId: state.realestate?.address?.city?.id,
      );

      // Le serveur renvoie le secteur existant si le nom est deja pris :
      // on evite ainsi les doublons dans la liste.
      List<Secteur> liste = [...(state.secteurs ?? [])];
      if (!liste.any((s) => s.id == secteur.id)) {
        liste = [...liste, secteur]..sort(
            (a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      }

      Realestate realestate = state.realestate ?? Realestate();
      emit(state.copyWith(
        secteurs: liste,
        realestate: realestate.copyWith(secteur: secteur),
      ));
    } catch (ex) {
      emit(state.copyWith(error: "Impossible de créer le secteur"));
    }
  }

  FutureOr<void> _addOwner(AddOwner event, Emitter<AddModifyImmState> emit) {
    List<Owner> newOwners=state.owners??[];
    newOwners=[...newOwners,event.owner];
    Realestate realestate=state.realestate??Realestate();
    emit(state.copyWith(owners: newOwners,realestate: realestate.copyWith(owner: event.owner)));
  }
}
