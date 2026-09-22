import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:widget_and_text_animator/widget_and_text_animator.dart';

import '../core/constants/app_colors.dart';





class MyLoadingIndicator extends StatelessWidget {
  MyLoadingIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated container with gradient background
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryColor.withOpacity(0.1),
                AppColors.primaryColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: SpinKitPouringHourGlass(
            color: AppColors.primaryColor,
            size: 50,
          ),
        ),
        const SizedBox(height: 24),
        // Animated text
        TextAnimator(
          "Chargement...",
          style: const TextStyle(
            color: AppColors.primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
         /* incomingEffect: WidgetTransitionEffects.incomingSlideInFromTop(
            duration: const Duration(milliseconds: 400),
          ),*/
          atRestEffect: WidgetRestingEffects.pulse(
            duration: const Duration(milliseconds: 500),
          ),
        ),
        const SizedBox(height: 8),
        // Subtitle text
        TextAnimator(
          "Please wait a moment",
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          /*incomingEffect: WidgetTransitionEffects.incomingSlideInFromBottom(
            delay: const Duration(milliseconds: 200),
            duration: const Duration(milliseconds: 400),
          ),*/
          atRestEffect: WidgetRestingEffects.pulse(
            duration: const Duration(milliseconds: 500),
          ),
        ),
        const SizedBox(height: 16),
        // Animated dots indicator
       /* Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: AppColors.primaryColor,
                size: 30,
              ),
            );
          }),
        ),*/
      ],
    );
  }
}
