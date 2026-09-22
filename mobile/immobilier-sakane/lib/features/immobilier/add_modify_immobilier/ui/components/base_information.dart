import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:immobilier/components/custom_button.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/bloc/add_modify_imm_bloc.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/routes.dart';

import '../../../../../components/form_field.dart';
import '../../../../../core/validator/validator.dart';
import '../../../../../models/category.dart';
import '../../../../../models/etat.dart';
import '../../../../../models/owner.dart';
import '../../../../../models/type_transaction.dart';
import 'package:immobilier/core/constants/app_colors.dart';



class BaseInformation extends StatefulWidget {
  void Function()? onNext;

  /// Etape precedente, s'il y en a une (aucune a l'ajout : c'est la premiere etape).
  final void Function()? onPrevious;

  BaseInformation({this.onNext, this.onPrevious});

  @override
  State<BaseInformation> createState() => _BaseInformationState();
}

class _BaseInformationState extends State<BaseInformation> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _virtualUrlController = TextEditingController();
  late final AddModifyImmBloc _bloc;

  @override
  void dispose() {
    if (_bloc.instantaneEtape == _instantane) _bloc.instantaneEtape = null;
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _virtualUrlController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Le brouillon lit la saisie de l'etape affichee.
    _bloc = BlocProvider.of<AddModifyImmBloc>(context);
    _bloc.instantaneEtape = _instantane;
    WidgetsBinding.instance.addPostFrameCallback((_){
      remplirFields();
    });
  }

  /// La saisie en cours, sans validation.
  Realestate _instantane() {
    Realestate realestate = getRealEstate();
    realestate.tour360Url = _virtualUrlController.text.isNotEmpty ? _virtualUrlController.text : null;
    Realestate nr = realestate.copyWith(
      title: _titleController.text,
      description: _descController.text,
      price: double.tryParse(_priceController.text.trim().replaceAll(',', '.')),
    );
    updateRealestate(nr);
    return nr;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddModifyImmBloc, AddModifyImmState>(
      builder: (context, state) {

        String? log=BlocProvider.of<AddModifyImmBloc>(context).state.realestate?.toString();
        print("============$log");

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
                        Icons.info_outline,
                        size: 48,
                        color: AppColors.primaryColor,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Informations de base du bien",
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

                /// Titre
                MyFormField(
                  label: "Titre *",
                  hint: "Entrez le titre",
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  controller: _titleController,
                  validator: Validator().required().min(3).make(),
                ),
                const SizedBox(height: 16),

                /// Description
                MyFormField(
                  label: "Description *",
                  hint: "Entrez la description",
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  controller: _descController,
                  isLarge: true,
                  validator: Validator().required().min(10).make(),
                ),
                const SizedBox(height: 16),

                /// Prix
                MyFormField(
                  label: state.realestate?.typeTransaction?.value == 'selle' ? "Prix de vente (MAD) *" : "Prix *",
                  hint: state.realestate?.typeTransaction?.value == 'selle' ? "Prix de vente demandé" : "Entrez le prix",
                  controller: _priceController,
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  inputType: TextInputType.number,
                  validator: Validator()
                      .required()
                      .number()
                      .greaterThan(0)
                      .make(),
                ),
                const SizedBox(height: 16),

                /// Lien virtuel
                MyFormField(
                  label: "Lien virtuel (360°)",
                  hint: "https://...",
                  controller: _virtualUrlController,
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  inputType: TextInputType.url,
                ),
                const SizedBox(height: 16),

                /// Catégorie
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Catégorie *",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<Category>(
                      value: state.realestate?.category,
                      items: state.categories?.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c.name!));
                      }).toList(),
                      decoration: _inputDecoration(hint: "Sélectionnez une catégorie"),
                      onChanged: onCategoryChanged,
                      validator: (val) =>
                      val == null ? "Veuillez choisir une catégorie" : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                /// État
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "État *",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<Etat>(
                      value: state.realestate?.etat,
                      items: state.etats?.map((e) {
                        return DropdownMenuItem(value: e, child: Text(e.name!));
                      }).toList(),
                      decoration: _inputDecoration(hint: "Sélectionnez un état"),
                      onChanged: onEtatChanged,
                      validator: (val) =>
                      val == null ? "Veuillez choisir un état" : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                /// Type transaction
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Type de transaction *",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<TypeTransaction>(
                      value: state.realestate?.typeTransaction,
                      items: state.typeTransaction?.map((t) {
                        return DropdownMenuItem(value: t, child: Text(t.name!));
                      }).toList(),
                      decoration: _inputDecoration(hint: "Sélectionnez un type de transaction"),
                      onChanged: onTypeTransactionChanged,
                      validator: (val) =>
                      val == null ? "Veuillez choisir un type" : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                /// Propriétaire
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Propriétaire",
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
                          child: DropdownButtonFormField<Owner>(
                            value: state.realestate?.owner,
                            items: state.owners?.map((o) {
                              return DropdownMenuItem(value: o, child: Text(o.name!));
                            }).toList(),
                            decoration: _inputDecoration(hint: "Sélectionnez un propriétaire"),
                            onChanged: onOwnerChanged,
                            /* validator: (val) =>
                            val == null ? "Veuillez choisir un propriétaire" : null,*/
                          ),
                        ),
                        const SizedBox(width: 10,),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: onAddOwner,
                            icon: Icon(Icons.add, color: Colors.white),
                            tooltip: "Ajouter un propriétaire",
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Action button
                Row(
                  children: [
                    if (widget.onPrevious != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _instantane();
                            widget.onPrevious?.call();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text("Précédent", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                    onPressed: onSuivantClick,
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

  void onSuivantClick() {
    if(_formKey.currentState?.validate()??false){
      Realestate realestate=getRealEstate();
      realestate.tour360Url= _virtualUrlController.text.isNotEmpty?_virtualUrlController.text:null;
      Realestate nr=realestate.copyWith(
        title: _titleController.text,
        description: _descController.text,
        price: double.parse(_priceController.text),

      );
      updateRealestate(nr);
      widget.onNext?.call();
    }
  }

  void remplirFields() {
    Realestate? realestate=BlocProvider.of<AddModifyImmBloc>(context).state.realestate;
    if(realestate!=null){
      _titleController.text=realestate.title??"";
      _descController.text=realestate.description??"";
      _priceController.text=realestate.price?.toString()??"";
      _virtualUrlController.text=realestate.tour360Url??"";
    }
  }

  void onCategoryChanged(Category? value) {
    print("changed");
    Realestate realestate=getRealEstate();
    Realestate nr=realestate.copyWith(category: value);
    updateRealestate(nr);
  }

  void onEtatChanged(Etat? value) {
    Realestate realestate=getRealEstate();
    Realestate nr= realestate.copyWith(etat: value);
    updateRealestate(nr);
  }

  void onTypeTransactionChanged(TypeTransaction? value) {
    Realestate realestate=getRealEstate();
    Realestate nr= realestate.copyWith(typeTransaction: value);
    updateRealestate(nr);
  }

  void onOwnerChanged(Owner? value) {
    Realestate realestate=getRealEstate();
    Realestate nr=realestate.copyWith(owner: value);
    updateRealestate(nr);
  }

  void updateRealestate(Realestate realestate){
    BlocProvider.of<AddModifyImmBloc>(context).add(UpdateRealestate(realestate));
  }

  Realestate getRealEstate(){
    Realestate? realestate=BlocProvider.of<AddModifyImmBloc>(context).state.realestate ?? Realestate();
    return realestate;
  }

  void onAddOwner() async{
    var result=await GoRouter.of(context).push(Routes.addOwner);
    if(result is Owner){
      BlocProvider.of<AddModifyImmBloc>(context).add(AddOwner(result));
    }
  }
}

/*
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:immobilier/components/custom_button.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/bloc/add_modify_imm_bloc.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/routes.dart';

import '../../../../../components/form_field.dart';
import '../../../../../core/validator/validator.dart';
import '../../../../../models/category.dart';
import '../../../../../models/etat.dart';
import '../../../../../models/owner.dart';
import '../../../../../models/type_transaction.dart';

class BaseInformation extends StatefulWidget {
  void Function()? onNext;

  BaseInformation({this.onNext});

  @override
  State<BaseInformation> createState() => _BaseInformationState();
}

class _BaseInformationState extends State<BaseInformation> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _virtualUrlController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _virtualUrlController.dispose();
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
    return BlocBuilder<AddModifyImmBloc, AddModifyImmState>(
      builder: (context, state) {

        String? log=BlocProvider.of<AddModifyImmBloc>(context).state.realestate?.toString();
        print("============$log");

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                /// Titre
                MyFormField(
                  label: "Titre",
                  hint: "Entrez le titre",
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  controller: _titleController,
                  validator: Validator().required().min(3).make(),
                ),
                const SizedBox(height: 10),

                /// Description
                MyFormField(
                  label: "Description",
                  hint: "Entrez la description",
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  controller: _descController,
                  isLarge: true,
                  validator: Validator().required().min(10).make(),
                ),
                const SizedBox(height: 10),

                /// Prix
                MyFormField(
                  label: "Prix",
                  hint: "Entrez le prix",
                  controller: _priceController,
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  inputType: TextInputType.number,
                  validator: Validator()
                      .required()
                      .number()
                      .greaterThan(0)
                      .make(),
                ),
                const SizedBox(height: 10),

                /// Lien virtuel
                MyFormField(
                  label: "Lien virtuel (360°)",
                  hint: "https://...",
                  controller: _virtualUrlController,
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  inputType: TextInputType.url,
                  //validator: Validator().make(),
                ),
                const SizedBox(height: 18),

                /// Catégorie
                DropdownButtonFormField<Category>(
                  value: state.realestate?.category,
                  items: state.categories?.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c.name!));
                  }).toList(),
                  decoration: inputDecoration(hint: "Sélectionnez une catégorie"),
                  onChanged: onCategoryChanged,
                  validator: (val) =>
                  val == null ? "Veuillez choisir une catégorie" : null,
                ),
                const SizedBox(height: 10),

                /// État
                DropdownButtonFormField<Etat>(
                  value: state.realestate?.etat,
                  items: state.etats?.map((e) {
                    return DropdownMenuItem(value: e, child: Text(e.name!));
                  }).toList(),
                  decoration: inputDecoration(hint: "Sélectionnez un état"),
                  onChanged: onEtatChanged,
                  validator: (val) =>
                  val == null ? "Veuillez choisir un état" : null,
                ),
                const SizedBox(height: 10),

                /// Type transaction
                DropdownButtonFormField<TypeTransaction>(
                  value: state.realestate?.typeTransaction,
                  items: state.typeTransaction?.map((t) {
                    return DropdownMenuItem(value: t, child: Text(t.name!));
                  }).toList(),
                  decoration:
                  inputDecoration(hint: "Sélectionnez un type de transaction"),
                  onChanged: onTypeTransactionChanged,
                  validator: (val) =>
                  val == null ? "Veuillez choisir un type" : null,
                ),
                const SizedBox(height: 10),
                /// Propriétaire
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Owner>(
                        value: state.realestate?.owner,
                        items: state.owners?.map((o) {
                          return DropdownMenuItem(value: o, child: Text(o.name!));
                        }).toList(),
                        decoration:
                        inputDecoration(hint: "Sélectionnez un propriétaire"),
                        onChanged: onOwnerChanged,
                       /* validator: (val) =>
                        val == null ? "Veuillez choisir un propriétaire" : null,*/
                      ),
                    ),
                    const SizedBox(width: 10,),
                    IconButton(onPressed: onAddOwner, icon: Icon(Icons.add,color: Colors.black,))
                  ],
                ),
                const SizedBox(height: 20),
                MyCustomButton(
                    name: "Suivant",
                  onClick: onSuivantClick,
                )
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration inputDecoration({String? hint, String? label}) =>
      InputDecoration(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.black54, fontSize: 15),
        filled: true,
        fillColor: Colors.grey.shade200, // light background color
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none, // no border
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

  void onSuivantClick() {
   if(_formKey.currentState?.validate()??false){
     Realestate realestate=getRealEstate();
     realestate.tour360Url= _virtualUrlController.text.isNotEmpty?_virtualUrlController.text:null;
     Realestate nr=realestate.copyWith(
       title: _titleController.text,
       description: _descController.text,
       price: double.parse(_priceController.text),

     );
     updateRealestate(nr);
     widget.onNext?.call();
   }
  }

  void remplirFields() {
    Realestate? realestate=BlocProvider.of<AddModifyImmBloc>(context).state.realestate;
    if(realestate!=null){
      _titleController.text=realestate.title??"";
      _descController.text=realestate.description??"";
      _priceController.text=realestate.price?.toString()??"";
      _virtualUrlController.text=realestate.tour360Url??"";
    }
   }


  void onCategoryChanged(Category? value) {
      print("changed");
      Realestate realestate=getRealEstate();
      Realestate nr=realestate.copyWith(category: value);
      updateRealestate(nr);
  }

  void onEtatChanged(Etat? value) {
    Realestate realestate=getRealEstate();
    Realestate nr= realestate.copyWith(etat: value);
    updateRealestate(nr);
  }

  void onTypeTransactionChanged(TypeTransaction? value) {
    Realestate realestate=getRealEstate();
    Realestate nr= realestate.copyWith(typeTransaction: value);
    updateRealestate(nr);
  }

  void onOwnerChanged(Owner? value) {
    Realestate realestate=getRealEstate();
    Realestate nr=realestate.copyWith(owner: value);
    updateRealestate(nr);
  }

  void updateRealestate(Realestate realestate){
    BlocProvider.of<AddModifyImmBloc>(context).add(UpdateRealestate(realestate));
  }
  Realestate getRealEstate(){
    Realestate? realestate=BlocProvider.of<AddModifyImmBloc>(context).state.realestate ?? Realestate();
    return realestate;
  }


  void onAddOwner() async{
    var result=await GoRouter.of(context).push(Routes.addOwner);
    if(result is Owner){
      BlocProvider.of<AddModifyImmBloc>(context).add(AddOwner(result));
    }
  }
}
*/