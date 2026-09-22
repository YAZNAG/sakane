


import 'dart:io';

import 'package:dio/dio.dart';

Map<String,dynamic> cleanMap(Map<String,dynamic> data){
  Map<String,dynamic> res={};
  for(String key in data.keys){
    if(data[key]!=null){
      res[key]=data[key];
    }
  }
  return res;
}


Future<MultipartFile?> convertFileToMF(File? file)async{
  if(file==null)return null;
  MultipartFile multipartFile=await MultipartFile.fromFile(file!.path);
  return multipartFile;
}