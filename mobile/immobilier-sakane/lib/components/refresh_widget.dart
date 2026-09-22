import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';



class RefreshWidget extends StatelessWidget {
  Future<void> Function() refresh;
  Widget child;
   RefreshWidget({required this.refresh,required this.child});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.foregroundColor,
        onRefresh:refresh,
        child: child,
    );
  }
}
