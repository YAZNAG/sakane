import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/bloc/add_modify_imm_bloc.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/assistant_bien_commun.dart';
import 'package:immobilier/features/immobilier/select_position/select_position.dart';
import 'package:immobilier/models/address.dart';
import 'package:immobilier/models/city.dart';
import 'package:immobilier/models/location.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/models/region.dart';
import 'package:immobilier/models/dossier.dart';

/// Étape 2 — Localisation.
///
/// L'adresse, la région, la ville, le dossier de rangement et le point sur
/// la carte : où se trouve le bien, et sous quel nom le retrouver.
class PropertyLocation extends StatefulWidget {
  final void Function()? onNext;
  final void Function()? onPrevious;
  final void Function()? onBrouillon;

  const PropertyLocation({super.key, this.onNext, this.onPrevious, this.onBrouillon});

  @override
  State<PropertyLocation> createState() => _PropertyLocationState();
}

class _PropertyLocationState extends State<PropertyLocation> {
  final _formKey = GlobalKey<FormState>();
  final _defilement = ScrollController();

  final _adresseCle = GlobalKey<FormFieldState<String>>();
  final _regionCle = GlobalKey<FormFieldState<Region>>();
  final _villeCle = GlobalKey<FormFieldState<City>>();

  final _addressController = TextEditingController();
  LatLng selectedLocation = LatLng(30.4278, -9.5981);
  GoogleMapController? _mapController;
  late final AddModifyImmBloc _bloc;

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

  @override
  void dispose() {
    if (_bloc.instantaneEtape == _instantane) _bloc.instantaneEtape = null;
    _defilement.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Realestate _instantane() => saveInformation();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddModifyImmBloc, AddModifyImmState>(
      builder: (context, state) {
        return Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: CorpsEtapeBien(
                  defilement: _defilement,
                  enfants: [
                    ChampTexteBien(
                      cle: _adresseCle,
                      libelle: 'Adresse complète',
                      indication: 'Rue, numéro, résidence…',
                      controller: _addressController,
                      lignes: 3,
                      casse: TextCapitalization.sentences,
                      validateur: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return "Indiquez l'adresse du bien.";
                        if (t.length < 5) return 'Au moins 5 caractères.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    ChampListeBien<Region>(
                      cle: _regionCle,
                      libelle: 'Région',
                      indication: 'Choisir une région',
                      valeur: parmiListeBien(state.regions, state.realestate?.address?.region),
                      choix: (state.regions ?? [])
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.name ?? '',
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChange: onRegionChanged,
                      validateur: (v) => v == null ? 'Choisissez une région.' : null,
                    ),
                    const SizedBox(height: 16),

                    ChampListeBien<City>(
                      cle: _villeCle,
                      libelle: 'Ville',
                      indication: 'Choisir une ville',
                      valeur: parmiListeBien(state.cities, state.realestate?.address?.city),
                      choix: (state.cities ?? [])
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name ?? '',
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChange: onCityChanged,
                      validateur: (v) => v == null ? 'Choisissez une ville.' : null,
                    ),
                    const SizedBox(height: 16),

                    _dossier(state),
                    const SizedBox(height: 16),

                    _carte(),
                  ],
                ),
              ),
              BarreActionsBien(
                libelleSuivant: suivantsEtapesBien[1],
                onSuivant: onNextClick,
                onPrecedent: onPreviousClick,
                onBrouillon: widget.onBrouillon,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Le dossier : le rangement des biens de l'agence. L'agent choisit un
  /// dossier existant, ou en crée un quand il en a le droit.
  Widget _dossier(AddModifyImmState state) {
    final liste = ChampListeBien<Dossier>(
      libelle: 'Dossier',
      indication: 'Choisir un dossier',
      valeur: parmiListeBien(state.dossiers, state.realestate?.dossier),
      choix: (state.dossiers ?? [])
          .map((d) => DropdownMenuItem(
                value: d,
                child: Text(d.nom ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChange: onDossierChanged,
    );
    if (!peut(AppPermission.createFolder)) return liste;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        liste,
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAjouterDossier,
            icon: const Icon(Icons.add, size: 17),
            label: const Text(
              'Nouveau dossier',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              foregroundColor: principaleBien,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          ),
        ),
      ],
    );
  }

  /// La carte, et le bouton qui ouvre le choix de la position.
  Widget _carte() {
    final hauteur = MediaQuery.sizeOf(context).height * .32;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LibelleChampBien('Position sur la carte'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: bordureAccueil),
            borderRadius: BorderRadius.circular(rayonAccueil),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(rayonAccueil - 1),
            child: Stack(
              children: [
                SizedBox(
                  height: hauteur,
                  width: double.infinity,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: selectedLocation, zoom: 12),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _mapController!.moveCamera(CameraUpdate.newLatLng(selectedLocation));
                    },
                    markers: {
                      Marker(markerId: const MarkerId("selected"), position: selectedLocation),
                    },
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(rayonChampBien),
                    elevation: 2,
                    child: InkWell(
                      onTap: onPickLocation,
                      borderRadius: BorderRadius.circular(rayonChampBien),
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(12, 9, 12, 9),
                        child: Row(
                          children: [
                            Icon(Icons.my_location, size: 17, color: principaleBien),
                            SizedBox(width: 7),
                            Text(
                              'Placer le bien',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: principaleBien,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Navigation ───────────────────────────────────────────────────

  void onNextClick() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      allerAuPremierFautifBien([_adresseCle, _regionCle, _villeCle]);
      return;
    }
    saveInformation();
    widget.onNext?.call();
  }

  void onPreviousClick() {
    saveInformation();
    widget.onPrevious?.call();
  }

  void remplirFields() {
    Realestate? realestate =
        BlocProvider.of<AddModifyImmBloc>(context).state.realestate;
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
    BlocProvider.of<AddModifyImmBloc>(context).add(UpdateRealestate(realestate));
  }

  Realestate getRealEstate() {
    Realestate? realestate =
        BlocProvider.of<AddModifyImmBloc>(context).state.realestate ?? Realestate();
    return realestate;
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Nouveau dossier",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: decorationChampBien(indication: "Ex : RESIDENCE NASSER"),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: principaleBien,
              foregroundColor: Colors.white,
            ),
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

  void onPickLocation() async {
    var result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LocationSelector(initialLocation: selectedLocation),
      ),
    );

    if (result is LatLng) {
      setState(() {
        selectedLocation = result;
        _mapController?.moveCamera(CameraUpdate.newLatLng(selectedLocation));
      });
    }
  }

  Realestate saveInformation() {
    Realestate realestate = getRealEstate();
    Address address = realestate.address ?? Address();
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
