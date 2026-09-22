import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:toastification/toastification.dart';

import '../dependencies/dependencies.dart';


void showToast(String msg,BuildContext context,{bool isDismissable=false, Color titleColor=Colors.white,Color descColor=Colors.white,int second=2,String? description,ToastificationType type=ToastificationType.success,VoidCallback? whenComplete}){
  try{
    ToastificationItem toastificationItem=Dependencies.get<ToastificationItem>();
    toastification.dismiss(toastificationItem);
  }catch(ex){

  }
  ToastificationItem toastificationItem = toastification.show(
    context: context, // optional if you use ToastificationWrapper
    type: type,
    dragToClose: isDismissable,
    style: ToastificationStyle.fillColored,
    autoCloseDuration:  Duration(seconds: second),
    title: Text(msg,style: GoogleFonts.aBeeZee(color:titleColor,fontSize:16,fontWeight:FontWeight.bold),),
    description: description!=null
        ?Text(description,style: GoogleFonts.aBeeZee(color:descColor,fontSize:15,fontWeight:FontWeight.normal),)
        :null,
    alignment: Alignment.topRight,
    direction: TextDirection.ltr,
    animationDuration: const Duration(milliseconds: 300),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    borderRadius: BorderRadius.circular(12),
    boxShadow: const [
      BoxShadow(
        color: Color(0x07000000),
        blurRadius: 16,
        offset: Offset(0, 16),
        spreadRadius: 0,
      )
    ],
    showProgressBar: true,
    closeButtonShowType: CloseButtonShowType.none,
    closeOnClick: false,
    applyBlurEffect: true,
    callbacks: ToastificationCallbacks(
      onAutoCompleteCompleted: (toastItem) => whenComplete?.call(),
    ),
  );
  Dependencies.put(toastificationItem);
}