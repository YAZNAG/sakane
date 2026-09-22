import 'package:flutter/cupertino.dart';

enum Components{
  letters,
  numbers,
  symbols
}
typedef ValidatorFaunction=String? Function(String?);

class Validator{
  bool? _isEmail;
  bool? _isNumber;
  bool? _notNumber;
  bool? _isRequired;
  bool? _isInteger;
  int? _max;
  int? _min;
  int? _gt;
  int? _lt;

  List<Components>? _contains;

  TextEditingController? _passwordController;



  //patterns
  RegExp _emailExp=RegExp(r'^\w+([.-]\w+)*@\w+([.-]\w+)*\.\w+$');
  RegExp _onlyNumberExp=RegExp(r'^[0-9]+(\.[0-9]+)?$');
  RegExp _onlyIntegers=RegExp(r'^[0-9]+$');
  RegExp _numberExp=RegExp(r'[0-9]+');
  RegExp _charExp=RegExp(r'[a-zA-Z]+');
  RegExp _onlyCharExp=RegExp(r'^[a-zA-Z]+$');
  RegExp _symbolsExp=RegExp(r'[^a-zA-Z\d]+');



  String _email = 'Email incorrect';
  String _number = 'Numéro incorrect';
  String _string = 'Texte incorrect';
  String _requiredMsg = 'Champ obligatoire';
  String _integer = 'Nombre incorrect';
  String _password = 'Le mot de passe ne correspond pas';




  Validator required(){
    _isRequired=true;
    return this;
  }
  Validator confirmPass(TextEditingController controller){
    _passwordController=controller;
    return this;
  }
  Validator email(){
    _isEmail=true;
    return this;
  }
  Validator number(){
    _isNumber=true;
    return this;
  }
  Validator text(){
    _notNumber=true;
    return this;
  }
  Validator max(int max){
    _max=max;
    return this;
  }
  Validator min(int min){
    _min=min;
    return this;
  }
  Validator greaterThan(int gt){
    _gt=gt;
    return this;
  }
  Validator lessThan(int ls){
    _lt=ls;
    return this;
  }
  Validator contains(List<Components> components){
    _contains=components;
    return this;
  }
  Validator integer(){
    _isInteger=true;
    return this;
  }


  ValidatorFaunction make(){
    return (value){
      if(!(_isRequired ?? false) && (value ?? "").isEmpty){
        return null;
      }
      if((_isRequired ?? false) && ((value ?? "").trim().isEmpty)){
        return _requiredMsg;
      }
      if((_isEmail ?? false) && !_emailExp.hasMatch(value!)){
        return _email;
      }
      if(  (_isNumber ?? false) && !_onlyNumberExp.hasMatch(value!) ){
        return _number;
      }
      if(  (_isInteger ??false) && !_onlyIntegers.hasMatch(value!) ){
        return _integer;
      }
      if((_notNumber ?? false) && !_onlyCharExp.hasMatch(value!)){
        return _string;
      }
      if( (_min!=null) && value!.length<_min! ){
        return 'min:$_min';
      }
      if(   (_max !=null) && value!.length>_max! ){
        return 'max:$_max';
      }

      if((_passwordController!=null) && (value ?? '')!=_passwordController!.text){
        return _password;
      }


      if(   (_lt !=null)){
        if(!_onlyNumberExp.hasMatch(value!)){
          return _number;
        }
        else{
          double dbl=double.parse(value);
          if(dbl>=_lt!){
            return 'doit être inférieur à:$_lt';
          }
        }
      }

      if(   (_gt !=null)){
        if(!_onlyNumberExp.hasMatch(value!)){
          return _number;
        }
        else{
          double dbl=double.parse(value);
          if(dbl<=_gt!){
            return 'doit être supérieur à:$_gt';
          }
        }
      }

      if(_contains!=null){
        String msg='';
        if(_contains!.contains(Components.letters) && !_charExp.hasMatch(value!)){
          msg+='lettres,';
        }
        if(_contains!.contains(Components.numbers) && !_numberExp.hasMatch(value!)){
          msg+='nombres,';
        }
        if(_contains!.contains(Components.symbols) && !_symbolsExp.hasMatch(value!)){
          msg+='symboles,';
        }

        if(msg.isNotEmpty){
          return 'doit contenir:${msg.substring(0,msg.length-1)}';
        }


      }



    };
  }


}
