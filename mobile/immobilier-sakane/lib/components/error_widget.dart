import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_images.dart';
import 'custom_button.dart';








class MyErrorWidget extends StatelessWidget {
  String error;
  String action;
  void Function()? actionCLick;
  bool showSecondBtn;
  String? secondBtn;
  void Function()? onSecondBtnClick;

  MyErrorWidget({required this.error,required this.action,this.actionCLick,this.showSecondBtn=false,this.secondBtn,this.onSecondBtnClick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(AppImages.img_error,fit: BoxFit.cover,),
          const SizedBox(height: 25,),
          Text(error,textAlign: TextAlign.center,style: GoogleFonts.poppins(color:Colors.red,fontWeight:FontWeight.bold,fontSize:17),),
          const SizedBox(height: 25,),
          if(action.length>0)
          MyCustomButton(name: action,height: 44,width: 230,borderRadius: 22,color:Colors.red,onClick: actionCLick,),
          SizedBox(height: 10,),
          if(showSecondBtn)
          MyCustomButton(name: secondBtn??"",height: 44,width: 230,borderRadius: 22,color:AppColors.primaryColor,onClick: onSecondBtnClick,)
        ],
      ),
    );
  }
}


