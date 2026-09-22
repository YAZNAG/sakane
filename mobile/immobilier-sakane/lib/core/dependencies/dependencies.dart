import 'package:flutter/material.dart';



class Dependencies{
  static Map<String,dynamic> _dependencies={};

  static S put<S>(S dep,{String? name}){
    String key=_getKey(S,name);
    _dependencies[key]=dep;
    return dep;
  }

  static S get<S>({String? name}){
    String key=_getKey(S, name);
    var dep= _dependencies[key];
    if(dep==null){
      throw Exception('Dependency :${S.toString()} not found!!');
    }
    return dep;
  }

  static String _getKey(Type s, String? name) {
    return name==null?s.toString():s.toString()+name;
  }

}
