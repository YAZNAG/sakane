import 'package:flutter/material.dart';

import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../../core/constants/app_colors.dart';



class MyCustomCircleBar extends StatelessWidget {
   MyCustomCircleBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return  Center(
      child:Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20)
          ),
          child: Center(child: LoadingAnimationWidget.staggeredDotsWave(color:AppColors.primaryColor, size: 30)))
    );
  }
}


