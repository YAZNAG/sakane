import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import '../../../../../components/custom_button.dart';
import '../../../../../components/form_field.dart';
import '../../../../../core/validator/validator.dart';
import '../../../../../models/realestate.dart';
import '../../bloc/add_modify_imm_bloc.dart';
import 'package:immobilier/core/constants/app_colors.dart';
class PropertyDetails extends StatefulWidget {
  void Function()? onNext;
  void Function()? onPrevious;

  PropertyDetails({this.onPrevious, this.onNext});

  @override
  State<PropertyDetails> createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends State<PropertyDetails> {
  final _formKey = GlobalKey<FormState>();

  final _roomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _nbEtagesController = TextEditingController();
  final _surfaceController = TextEditingController();
  final _constructionDateController = TextEditingController();
  final _etageController = TextEditingController();
  late final AddModifyImmBloc _bloc;

  @override
  void dispose() {
    if (_bloc.instantaneEtape == _instantane) _bloc.instantaneEtape = null;
    _roomsController.dispose();
    _bathroomsController.dispose();
    _nbEtagesController.dispose();
    _constructionDateController.dispose();
    _etageController.dispose();
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

  /// Sans validation : un nombre mal saisi est simplement ignore.
  Realestate _instantane() {
    int? entier(TextEditingController c) => int.tryParse(c.text.trim());
    final realestate = getRealEstate();
    realestate.nbBathroom = entier(_bathroomsController);
    realestate.nbEtages = entier(_nbEtagesController);
    realestate.nbRooms = entier(_roomsController);
    realestate.surface = entier(_surfaceController) ?? num.tryParse(_surfaceController.text.trim().replaceAll(',', '.'));
    realestate.etage = entier(_etageController);
    final nr = realestate.copyWith();
    updateRealestate(nr);
    return nr;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
           /* Container(
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
                    Icons.home_work,
                    size: 48,
                    color: AppColors.primaryColor,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Détails de la propriété",
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

            // Form sections
            _buildFormSection(
              title: "Caractéristiques générales",
              icon: Icons.info_outline,
              children: [
                MyFormField(
                  label: "Surface (m²)",
                  hint: "Entrez la surface en m²",
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  controller: _surfaceController,
                  validator: Validator().integer().required().make(),
                  inputType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                MyFormField(
                  label: "Date de construction",
                  hint: "Sélectionnez une date",
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  controller: _constructionDateController,
                  readOnly: true,
                  onTap: _pickDate,
                  onSuffixClick: _pickDate,
                  suffix: Icon(Icons.calendar_month, color: Colors.grey),
                ),
              ],
            ),

            SizedBox(height: 24),

            _buildFormSection(
              title: "Distribution des espaces",
              icon: Icons.meeting_room,
              children: [
                MyFormField(
                  label: "Nombre de chambres",
                  hint: "Entrez le nombre de chambres",
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  controller: _roomsController,
                  validator: Validator().integer().make(),
                  inputType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                MyFormField(
                  label: "Nombre de salles de bain",
                  hint: "Entrez le nombre de salles de bain",
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  controller: _bathroomsController,
                  validator: Validator().integer().make(),
                  inputType: TextInputType.number,
                ),
              ],
            ),

            SizedBox(height: 24),

            _buildFormSection(
              title: "Informations sur les étages",
              icon: Icons.apartment,
              children: [
                MyFormField(
                  label: "Nombre total d'étages",
                  hint: "Entrez le nombre d'étages",
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  controller: _nbEtagesController,
                  validator: Validator().integer().make(),
                  inputType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                MyFormField(
                  label: "Étage du bien",
                  hint: "Entrez l'étage du bien",
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  controller: _etageController,
                  validator: Validator().integer().make(),
                  inputType: TextInputType.number,
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
  }

  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Colors.grey.shade700,
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        // Section content
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  void onNextClick() {
    if (_formKey.currentState?.validate() ?? false) {
      saveInformation();
      widget.onNext?.call();
    }
  }

  void onPreviousClick() {
    if (_formKey.currentState?.validate() ?? false) {
      saveInformation();
      widget.onPrevious?.call();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: DateTime(2015),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        initialEntryMode: DatePickerEntryMode.calendarOnly);

    if (picked != null) {
      Realestate realestate = getRealEstate();
      Realestate nr = realestate.copyWith(dateConstruction: picked);
      updateRealestate(nr);
      setState(() {
        _constructionDateController.text = picked.formattedDateFr;
      });
    }
  }

  void updateRealestate(Realestate realestate) {
    BlocProvider.of<AddModifyImmBloc>(context).add(UpdateRealestate(realestate));
  }

  Realestate getRealEstate() {
    Realestate? realestate =
        BlocProvider.of<AddModifyImmBloc>(context).state.realestate ??
            Realestate();
    return realestate;
  }

  void remplirFields() {
    Realestate? realestate =
        BlocProvider.of<AddModifyImmBloc>(context).state.realestate;
    if (realestate != null) {
      _surfaceController.text = realestate.surface?.toString() ?? "";
      _bathroomsController.text = realestate.nbBathroom?.toString() ?? "";
      _nbEtagesController.text = realestate.nbEtages?.toString() ?? "";
      _roomsController.text = realestate.nbRooms?.toString() ?? "";
      _constructionDateController.text =
          realestate.dateConstruction?.formattedDateFr ?? "";
      _etageController.text=realestate.etage?.toString()??"";
    }
  }

  void saveInformation() {
    Realestate realestate = getRealEstate();
    realestate.nbBathroom = _bathroomsController.text.isNotEmpty
        ? int.parse(_bathroomsController.text)
        : null;
    realestate.nbEtages = _nbEtagesController.text.isNotEmpty
        ? int.parse(_nbEtagesController.text)
        : null;
    realestate.nbRooms = _roomsController.text.isNotEmpty
        ? int.parse(_roomsController.text)
        : null;
    realestate.surface = _surfaceController.text.isNotEmpty
        ? int.parse(_surfaceController.text)
        : null;
    realestate.etage = _etageController.text.isNotEmpty
        ? int.parse(_etageController.text)
        : null;

    updateRealestate(realestate.copyWith());
  }
}


/*
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import '../../../../../components/custom_button.dart';
import '../../../../../components/form_field.dart';
import '../../../../../core/validator/validator.dart';
import '../../../../../models/realestate.dart';
import '../../bloc/add_modify_imm_bloc.dart';

class PropertyDetails extends StatefulWidget {
  void Function()? onNext;
  void Function()? onPrevious;

  PropertyDetails({this.onPrevious,this.onNext}) ;

  @override
  State<PropertyDetails> createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends State<PropertyDetails> {




  final _formKey = GlobalKey<FormState>();

  final _roomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _nbEtagesController = TextEditingController();
  final _surfaceController = TextEditingController();
  final _constructionDateController = TextEditingController();
  final _etageController = TextEditingController();

  @override
  void dispose() {
    _roomsController.dispose();
    _bathroomsController.dispose();
    _nbEtagesController.dispose();
    _constructionDateController.dispose();
    _etageController.dispose();
    super.dispose();
  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      remplirFields();
    });
  }



  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            /// Nombre de chambres
            MyFormField(
              label: "Nombre de chambres",
              hint: "Entrez le nombre de chambres",
              labelColor: Colors.black,
              borderColor: Colors.black,
              hintColor: Colors.black54,
              activeBorderColor: Colors.black,
              controller: _roomsController,
              validator: Validator().integer().make(),
              inputType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            /// Nombre de salles de bain
            MyFormField(
              label: "Nombre de salles de bain",
              hint: "Entrez le nombre de salles de bain",
              labelColor: Colors.black,
              borderColor: Colors.black,
              hintColor: Colors.black54,
              activeBorderColor: Colors.black,
              controller: _bathroomsController,
              validator: Validator().integer().make(),
              inputType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            /// Nombre de salles de bain
            MyFormField(
              label: "Surface",
              hint: "Entrez la surface en m²",
              labelColor: Colors.black,
              borderColor: Colors.black,
              hintColor: Colors.black54,
              activeBorderColor: Colors.black,
              controller: _surfaceController,
              validator: Validator().integer().make(),
              inputType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            /// Nombre d’étages
            MyFormField(
              label: "Nombre d’étages",
              hint: "Entrez le nombre d’étages",
              labelColor: Colors.black,
              borderColor: Colors.black,
              hintColor: Colors.black54,
              activeBorderColor: Colors.black,
              controller: _nbEtagesController,
              validator: Validator().integer().make(),
              inputType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            MyFormField(
              label: "Étage",
              hint: "Entrez l’étage du bien",
              labelColor: Colors.black,
              borderColor: Colors.black,
              hintColor: Colors.black54,
              activeBorderColor: Colors.black,
              controller: _etageController,
              validator: Validator().integer().make(),
              inputType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            /// Date de construction
            MyFormField(
              label: "Date de construction",
              hint: "Sélectionnez une date",
              labelColor: Colors.black,
              borderColor: Colors.black,
              hintColor: Colors.black54,
              activeBorderColor: Colors.black,
              controller: _constructionDateController,
              //validator: Validator().required().make(),
              readOnly: true,
              onTap: _pickDate,
              onSuffixClick: _pickDate,
              suffix: Icon(Icons.calendar_month,color:Colors.grey),
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
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  void onNextClick() {
    if(_formKey.currentState?.validate()??false){
      saveInformation();
      widget.onNext?.call();
    }
  }

  void onPreviousClick() {
    if(_formKey.currentState?.validate()??false){
      saveInformation();
      widget.onPrevious?.call();
    }
  }
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2015),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly
    );

    if (picked != null) {
      Realestate realestate=getRealEstate();
      Realestate nr=realestate.copyWith(dateConstruction: picked);
      updateRealestate(nr);
      setState(() {
        _constructionDateController.text =picked.formattedDateFr;
      });
    }
  }

  void updateRealestate(Realestate realestate){
    BlocProvider.of<AddModifyImmBloc>(context).add(UpdateRealestate(realestate));
  }
  Realestate getRealEstate(){
    Realestate? realestate=BlocProvider.of<AddModifyImmBloc>(context).state.realestate ?? Realestate();
    return realestate;
  }

  void remplirFields() {
    Realestate? realestate=BlocProvider.of<AddModifyImmBloc>(context).state.realestate;
    if(realestate!=null){
      _surfaceController.text=realestate.surface?.toString()??"";
      _bathroomsController.text=realestate.nbBathroom?.toString()??"";
      _nbEtagesController.text=realestate.nbEtages?.toString()??"";
      _roomsController.text=realestate.nbRooms?.toString()??"";
      _constructionDateController.text=realestate.dateConstruction?.formattedDateFr??"";
    }
  }
  void saveInformation(){
    Realestate realestate=getRealEstate();
    */
/*Realestate nr=realestate.copyWith(
        nbBathroom: _bathroomsController.text.isNotEmpty?int.parse(_bathroomsController.text):null,
        nbEtages:_nbEtagesController.text.isNotEmpty? int.parse(_nbEtagesController.text):null,
        nbRooms:_roomsController.text.isNotEmpty? int.parse(_roomsController.text):null,
        surface:_surfaceController.text.isNotEmpty? int.parse(_surfaceController.text):null,

    );*//*

    realestate.nbBathroom= _bathroomsController.text.isNotEmpty?int.parse(_bathroomsController.text):null;
    realestate.nbEtages=_nbEtagesController.text.isNotEmpty? int.parse(_nbEtagesController.text):null;
    realestate.nbRooms=_roomsController.text.isNotEmpty? int.parse(_roomsController.text):null;
    realestate.surface=_surfaceController.text.isNotEmpty? int.parse(_surfaceController.text):null;
    realestate.etage=_etageController.text.isNotEmpty? int.parse(_etageController.text):null;

    updateRealestate(realestate.copyWith());
  }

}
*/
