
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../components/text_button.dart';

import '../constants/app_images.dart';





Future<bool?> showDialogueQuestion(BuildContext context,String question,[String positive="Oui",String negative="Non"])async{
  bool? result=await showDialog(context: context, builder: (context){
    return AlertDialog(
      backgroundColor: Colors.white,
      icon: Center(child: Image.asset(AppImages.img_question,fit: BoxFit.cover,width: 150,)),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      content: Text(question,style: GoogleFonts.aBeeZee(fontSize: 18),textAlign: TextAlign.center,),
      actionsOverflowAlignment:OverflowBarAlignment.center ,
      actions: [
        MyTextButton(parts: [negative],icon:Icons.cancel_outlined,colors: [Colors.redAccent],onclick: ()=>Navigator.pop(context,false)),
        MyTextButton(parts: [positive],icon:Icons.check,colors: [Colors.green],onclick: ()=>Navigator.pop(context,true)),
      ],
    );
  });
  return result;
}

