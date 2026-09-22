




import 'package:immobilier/core/constants/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:immobilier/components/custom_button.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/core/utils/texts.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/bloc/add_modify_imm_bloc.dart';
import 'package:immobilier/features/immobilier/select_position/select_position.dart';
import 'package:immobilier/models/address.dart';
import 'package:immobilier/models/city.dart';
import 'package:immobilier/models/location.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/models/region.dart';
import 'package:immobilier/models/dossier.dart';
import '../../../../../components/form_field.dart';
import '../../../../../core/validator/validator.dart';

class PropertyLocation extends StatefulWidget {
  void Function()? onNext;
  void Function()? onPrevious;

  PropertyLocation({this.onNext, this.onPrevious});

  @override
  State<PropertyLocation> createState() => _PropertyLocationState();
}

class _PropertyLocationState extends State<PropertyLocation> {
  final _formKey = GlobalKey<FormState>();

  final _addressController = TextEditingController();
  LatLng selectedLocation = LatLng(30.4278, -9.5981);
  GoogleMapController? _mapController;
  late final AddModifyImmBloc _bloc;

  @override
  void dispose() {
    if (_bloc.instantaneEtape == _instantane) _bloc.instantaneEtape = null;
    _addressController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Le brouillon lit la saisie de l'etape affichee.
    _bloc = BlocProvider.of<AddModifyImmBloc>(context);
    _bloc.instantaneEtape = _instantane;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      remplirFields();
    });
  }

  Realestate _instantane() => saveInformation();

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.sizeOf(context).height;
    return BlocBuilder<AddModifyImmBloc, AddModifyImmState>(
      builder: (context, state) {
        print("address${state.realestate?.address?.city}");

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
              /*  Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 48,
                        color: AppColors.primaryColor,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Localisation de la propriété",
                        style: TextStyle(
                          color: AppColors.primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),*/

                SizedBox(height: 24),

                /// Adresse complète
                MyFormField(
                  label: "Adresse complète *",
                  hint: "Entrez l'adresse complète",
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  controller: _addressController,
                  isLarge: true,
                  validator: Validator().required().min(5).make(),
                ),
                const SizedBox(height: 16),

                /// Région
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Région *",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<Region>(
                      value: state.realestate?.address?.region,
                      items: state.regions?.map((r) {
                        return DropdownMenuItem(value: r, child: text(r.name!));
                      }).toList(),
                      decoration: _inputDecoration(hint: "Sélectionnez une région"),
                      onChanged: onRegionChanged,
                      validator: (val) =>
                      val == null ? "Veuillez choisir une région" : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                /// Ville
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ville *",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<City>(
                      value: state.realestate?.address?.city,
                      items: state.cities?.map((c) {
                        return DropdownMenuItem(value: c, child: text(c.name!));
                      }).toList(),
                      decoration: _inputDecoration(hint: "Sélectionnez une ville"),
                      onChanged: onCityChanged,
                      validator: (val) =>
                      val == null ? "Veuillez choisir une ville" : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                /// Dossier : le rangement des biens de l'agence.
                /// L'agent choisit un dossier existant, ou en cree un.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Dossier",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Dossier>(
                            value: _dossierCourant(state),
                            isExpanded: true,
                            items: (state.dossiers ?? []).map((dos) {
                              return DropdownMenuItem(
                                value: dos,
                                child: text(dos.nom ?? ''),
                              );
                            }).toList(),
                            decoration: _inputDecoration(
                                hint: "Sélectionnez un dossier"),
                            onChanged: onDossierChanged,
                          ),
                        ),
                        if (peut(AppPermission.createFolder)) ...[
                        const SizedBox(width: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: onAjouterDossier,
                            icon: Icon(Icons.add, color: Colors.white),
                            tooltip: "Nouveau dossier",
                          ),
                        ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Map section with title
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Position sur la carte",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: height * 0.4,
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: selectedLocation,
                                  zoom: 12,
                                ),
                                onMapCreated: (controller) {
                                  _mapController = controller;
                                  _mapController!.moveCamera(CameraUpdate.newLatLng(selectedLocation));
                                },
                                markers: {
                                  Marker(
                                    markerId: MarkerId("selected"),
                                    position: selectedLocation,
                                  ),
                                },
                              ),
                            ),
                            Positioned(
                              right: 12,
                              top: 12,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: onPickLocation,
                                  icon: Icon(
                                    Icons.my_location,
                                    color: Colors.white,
                                  ),
                                  tooltip: "Sélectionner la position",
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onPreviousClick,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Précédent",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onNextClick,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Suivant",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration({String? hint, String? label}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.black),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.black),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      );

  void onNextClick() {
    if (_formKey.currentState?.validate() ?? false) {
      saveInformation();
      widget.onNext?.call();
    }
  }

  void onPreviousClick() {
    saveInformation();
    widget.onPrevious?.call();
  }

  void remplirFields() {
    Realestate? realestate = BlocProvider.of<AddModifyImmBloc>(
      context,
    ).state.realestate;
    if (realestate != null) {
      setState(() {
        _addressController.text = realestate.address?.address ?? "";
        selectedLocation = LatLng(
          realestate.location?.latitude?.toDouble() ?? 30.4278,
          realestate.location?.longitude?.toDouble() ?? -9.5981,
        );
      });
    }
  }

  void onRegionChanged(Region? value) {
    if (value == null) return;
    BlocProvider.of<AddModifyImmBloc>(context).add(SelectRegion(value));
  }

  void updateRealestate(Realestate realestate) {
    BlocProvider.of<AddModifyImmBloc>(
      context,
    ).add(UpdateRealestate(realestate));
  }

  Realestate getRealEstate() {
    Realestate? realestate =
        BlocProvider.of<AddModifyImmBloc>(context).state.realestate ??
            Realestate();
    return realestate;
  }

  /// Le dossier retenu doit appartenir a la liste chargee, sinon la
  /// liste deroulante refuse de l'afficher.
  Dossier? _dossierCourant(AddModifyImmState state) {
    final choisi = state.realestate?.dossier;
    if (choisi == null) return null;
    final liste = state.dossiers ?? [];
    return liste.any((d) => d.id == choisi.id) ? choisi : null;
  }

  void onDossierChanged(Dossier? value) {
    if (value == null) return;
    updateRealestate(getRealEstate().copyWith(dossier: value));
  }

  /// Saisie d'un nouveau dossier. Le serveur renvoie le dossier existant
  /// si le nom est deja utilise, ce qui evite les doublons.
  void onAjouterDossier() async {
    final controller = TextEditingController();
    final nom = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nouveau dossier"),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: "Ex : RESIDENCE NASSER",
            labelText: "Nom du dossier",
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );

    if (nom != null && nom.isNotEmpty && mounted) {
      BlocProvider.of<AddModifyImmBloc>(context).add(AddDossier(nom));
    }
  }

  void onCityChanged(City? value) {
    if (value == null) return;
    Realestate realestate = getRealEstate();
    Address address = realestate.address ?? Address();
    Address na = address.copyWith(city: value);
    Realestate nr = realestate.copyWith(address: na);
    updateRealestate(nr);
  }

  void onPickLocation() async{
    var result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => LocationSelector(initialLocation: selectedLocation,)));

    if (result is LatLng) {
      setState(() {
        selectedLocation = result ;
        _mapController?.moveCamera(CameraUpdate.newLatLng(selectedLocation));
      });
    }
  }

  Realestate saveInformation(){
    Realestate realestate = getRealEstate();
    Address address = realestate.address??Address();
    Address na = address.copyWith(address: _addressController.text);
    Realestate nr = realestate.copyWith(
      address: na,
      location: Location(
        latitude: selectedLocation.latitude,
        longitude: selectedLocation.longitude,
      ),
    );
    updateRealestate(nr);
    return nr;
  }
}





/*
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:immobilier/components/custom_button.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/core/utils/texts.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/bloc/add_modify_imm_bloc.dart';
import 'package:immobilier/features/immobilier/select_position/select_position.dart';
import 'package:immobilier/models/address.dart';
import 'package:immobilier/models/city.dart';
import 'package:immobilier/models/location.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/models/region.dart';
import '../../../../../components/form_field.dart';
import '../../../../../core/validator/validator.dart';

class PropertyLocation extends StatefulWidget {
  void Function()? onNext;
  void Function()? onPrevious;

  PropertyLocation({this.onNext, this.onPrevious});

  @override
  State<PropertyLocation> createState() => _PropertyLocationState();
}

class _PropertyLocationState extends State<PropertyLocation> {
  final _formKey = GlobalKey<FormState>();

  final _addressController = TextEditingController();
  LatLng selectedLocation = LatLng(30.4278, -9.5981);
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      remplirFields();
    });
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.sizeOf(context).height;
    return BlocBuilder<AddModifyImmBloc, AddModifyImmState>(
      builder: (context, state) {
        print("address${state.realestate?.address?.city}");

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                /// Adresse complète
                MyFormField(
                  label: "Adresse complète",
                  hint: "Entrez l'adresse complète",
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  controller: _addressController,
                  isLarge: true,
                  validator: Validator().required().min(5).make(),
                ),
                const SizedBox(height: 10),

                /// Région
                DropdownButtonFormField<Region>(
                  value: state.realestate?.address?.region,
                  items: state.regions?.map((r) {
                    return DropdownMenuItem(value: r, child: text(r.name!));
                  }).toList(),
                  decoration: inputDecoration(hint: "Sélectionnez une région"),
                  onChanged: onRegionChanged,
                  validator: (val) =>
                      val == null ? "Veuillez choisir une région" : null,
                ),
                const SizedBox(height: 10),

                /// Ville
                DropdownButtonFormField<City>(
                  value: state.realestate?.address?.city,
                  items: state.cities?.map((c) {
                    return DropdownMenuItem(value: c, child: text(c.name!));
                  }).toList(),
                  decoration: inputDecoration(hint: "Sélectionnez une ville"),
                  onChanged: onCityChanged,
                  validator: (val) =>
                      val == null ? "Veuillez choisir une ville" : null,
                ),
                const SizedBox(height: 10),

                Stack(
                  children: [
                    SizedBox(
                      height: height * 0.4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: selectedLocation,
                            zoom: 12,
                          ),
                          onMapCreated: (controller) {
                            _mapController = controller;
                            _mapController!.moveCamera(CameraUpdate.newLatLng(selectedLocation));
                          },
                          //onTap: onSelectLocation,
                          markers: {
                            Marker(
                              markerId: MarkerId("selected"),
                              position: selectedLocation,
                            ),
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.withOpacity(0.7),
                        ),
                        child: IconButton(
                          onPressed: onPickLocation,
                          icon: Icon(Icons.location_on_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MyCustomButton(
                      name: "Précédent",
                      color: Colors.redAccent[100]!,
                      width: 150,
                      onClick: onPreviousClick,
                    ),
                    MyCustomButton(
                      name: "Suivant",
                      width: 150,
                      onClick: onNextClick,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration inputDecoration({String? hint, String? label}) =>
      InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.black54, fontSize: 15),
        filled: true,
        fillColor: Colors.grey.shade200,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );



  void onNextClick() {
    if (_formKey.currentState?.validate() ?? false) {
     saveInformation();
      widget.onNext?.call();
    }
  }

  void onPreviousClick() {
    saveInformation();
    widget.onPrevious?.call();
  }

  void remplirFields() {
    Realestate? realestate = BlocProvider.of<AddModifyImmBloc>(
      context,
    ).state.realestate;
    if (realestate != null) {
      setState(() {
        _addressController.text = realestate.address?.address ?? "";
        selectedLocation = LatLng(
          realestate.location?.latitude?.toDouble() ?? 30.4278,
          realestate.location?.longitude?.toDouble() ?? -9.5981,
        );
      });

    }
  }

  void onRegionChanged(Region? value) {
    if (value == null) return;
    BlocProvider.of<AddModifyImmBloc>(context).add(SelectRegion(value));
  }

  void updateRealestate(Realestate realestate) {
    BlocProvider.of<AddModifyImmBloc>(
      context,
    ).add(UpdateRealestate(realestate));
  }

  Realestate getRealEstate() {
    Realestate? realestate =
        BlocProvider.of<AddModifyImmBloc>(context).state.realestate ??
        Realestate();
    return realestate;
  }

  void onCityChanged(City? value) {
    if (value == null) return;
    Realestate realestate = getRealEstate();
    Address address = realestate.address ?? Address();
    Address na = address.copyWith(city: value);
    Realestate nr = realestate.copyWith(address: na);
    updateRealestate(nr);
  }

  void onPickLocation() async{
    var result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => LocationSelector(initialLocation: selectedLocation,)));

    if (result is LatLng) {
      setState(() {
        selectedLocation = result ;
        _mapController?.moveCamera(CameraUpdate.newLatLng(selectedLocation));
      });
    }
  }

  void saveInformation(){
    Realestate realestate = getRealEstate();
    Address address = realestate.address??Address();
    Address na = address.copyWith(address: _addressController.text);
    Realestate nr = realestate.copyWith(
      address: na,
      location: Location(
        latitude: selectedLocation.latitude,
        longitude: selectedLocation.longitude,
      ),
    );
    updateRealestate(nr);

  }

}
*/
