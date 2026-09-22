import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_images.dart';


class LoadingWidget extends StatelessWidget {
  const LoadingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(AppImages.app_logo,height: 170,),
        LoadingAnimationWidget.flickr(leftDotColor: AppColors.primaryColor, rightDotColor: Colors.black, size: 40)
      ],
    );
  }
}
