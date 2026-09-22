import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_images.dart';
import 'package:immobilier/core/utils/texts.dart';




class EmptyWidget extends StatelessWidget {
  String msg;
  double height;

  EmptyWidget({this.msg="Aucune donnée",this.height=120}) ;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(AppImages.img_empty,height: height,),
        const SizedBox(height: 10,),
        title(msg)
      ],
    );
  }
}
