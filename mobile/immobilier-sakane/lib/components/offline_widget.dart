import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_images.dart';
import 'custom_button.dart';





class OfflineWidget extends StatelessWidget {
  String msg;
  String action;
  void Function()? actionCLick;
  bool showAction;

  bool showSecondBtn;
  String? secondBtn;
  void Function()? onSecondBtnClick;

  OfflineWidget({required this.action,required this.msg,this.actionCLick,this.showAction=true,this.showSecondBtn=false,this.secondBtn,this.onSecondBtnClick});

  @override
  Widget build(BuildContext context) {

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ImageIcon(AssetImage(AppImages.img_offline),size: 120,color: Colors.red,),
        const SizedBox(height: 25,),
        Text(msg,style: GoogleFonts.poppins(color:AppColors.secondaryColor,fontWeight:FontWeight.bold,fontSize:17),),
        const SizedBox(height: 25,),
        if(showAction)
        MyCustomButton(name: action,height: 44,width: 230,borderRadius: 22,color: AppColors.secondaryColor,onClick: actionCLick,),

        SizedBox(height: 10,),

        if(showSecondBtn)
        MyCustomButton(name: secondBtn??"",height: 44,width: 230,borderRadius: 22,color:AppColors.primaryColor,onClick: onSecondBtnClick,)


      ],
    );
  }
}

