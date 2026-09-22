

import 'package:flutter/material.dart';


import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/enums/app_status.dart';
import 'custom_button.dart';



class DialogueInfos extends StatelessWidget {
  MessageUi message;
  Color dialogueColor,buttonColor;
  void Function()? onclickAction;

   DialogueInfos({
     required this.message,
     this.buttonColor=AppColors.primaryColor,
     this.dialogueColor=Colors.white,
     this.onclickAction
   });



  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: _icon(),

      content: Text(message.msg,style: GoogleFonts.aBeeZee(fontSize: 18,),textAlign: TextAlign.center,),
      backgroundColor: Colors.white,
      actions: [
        MyCustomButton(name: message.Action,width: 140,color:buttonColor,onClick: onclickAction,)
      ],
    );
  }
  Widget _icon(){
    double size=35;
    switch(message.status){
      case AppStatus.warning:
        return Icon(Icons.warning,color: Colors.orangeAccent,size: size,);
      case AppStatus.error:
        return Icon(Icons.error,color: Colors.redAccent,size: size,);
      case AppStatus.infos:
        return Icon(Icons.info_outline,color: Colors.lightBlue,size: size,);
      case AppStatus.loading:
        return Icon(Icons.downloading,color: Colors.lightBlue,size: size,);
      case AppStatus.success:
        return Icon(Icons.check,color: Colors.green,size: size,);
      default:
        return const Icon(Icons.ac_unit_outlined);
    }
  }
}


class MessageUi{
  String msg;
  AppStatus status;
  String Action;

  MessageUi(this.msg, this.status,this.Action);


}
