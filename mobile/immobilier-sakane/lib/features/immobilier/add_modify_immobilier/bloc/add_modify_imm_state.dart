part of 'add_modify_imm_bloc.dart';




class AddModifyImmState {
  AppStatus? fetchData;
  AppStatus? addModifyStatus;
  String? error;
  Realestate? realestate;
  int? realestateId;

  List<Etat>? etats;
  List<TypeTransaction>? typeTransaction;
  List<Category>? categories;
  List<City>? cities;
  List<Region>? regions;
  List<Feature>? features;

  /// Les types de biens, leurs caracteristiques propres et les
  /// equipements ranges par famille. Null quand le serveur ne l'a pas
  /// donne : le formulaire se contente alors de ses champs communs.
  FormulaireBien? formulaire;
  List<Owner>? owners;
  List<Secteur>? secteurs;
  List<Dossier>? dossiers;
  Map<String,dynamic>? errors;

  /*Etat? selectedEtat;
  TypeTransaction? selectedType;
  Category? selectedCategory;
  City? selectedCity;
  Region? selectedRegion;
  Owner? selectedOwner;

  List<File>? images;*/

  AddModifyImmState({
    this.fetchData,
    this.error,
    this.realestate,
    this.realestateId,
    this.etats,
    this.typeTransaction,
    this.categories,
    this.cities,
    this.regions,
    this.features,
    this.formulaire,
    this.owners,
    this.secteurs,
    this.dossiers,
    this.addModifyStatus,
    this.errors
  });

  AddModifyImmState copyWith({
    AppStatus? fetchStatus,
    String? error,
    List<Etat>? etats,
    List<TypeTransaction>? typeTransaction,
    List<Category>? categories,
    List<City>? cities,
    List<Region>? regions,
    List<Feature>? features,
    FormulaireBien? formulaire,
    List<Owner>? owners,
    List<Secteur>? secteurs,
    List<Dossier>? dossiers,
    Etat? selectedEtat,
    TypeTransaction? selectedType,
    Category? selectedCategory,
    City? selectedCity,
    Region? selectedRegion,
    Owner? selectedOwner,
    List<File>? images,
    int? realestateId,
    Realestate? realestate,
    AppStatus? addModifyStatus,
    Map<String,dynamic>? errors
  }) {
    return AddModifyImmState(
      fetchData: fetchStatus ?? this.fetchData,
      realestateId: realestateId??this.realestateId,
      realestate: realestate??this.realestate,
      error: error ,
      etats: etats ?? this.etats,
      typeTransaction: typeTransaction ?? this.typeTransaction,
      categories: categories ?? this.categories,
      cities: cities ?? this.cities,
      regions: regions ?? this.regions,
      features: features ?? this.features,
      formulaire: formulaire ?? this.formulaire,
      owners: owners ?? this.owners,
      secteurs: secteurs ?? this.secteurs,
      dossiers: dossiers ?? this.dossiers,
      addModifyStatus: addModifyStatus,
      errors: errors
    );
  }
}

