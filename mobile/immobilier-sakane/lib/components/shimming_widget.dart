
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_colors.dart';


class ShimmingWidget extends StatelessWidget {
  bool isRectangle,hasBorder;
  double width,height,borderRadius;
  Color? borderColor,shimmingColor,baseColor,shadowColor;
  bool hasShadow;
  
   ShimmingWidget({
     required this.width,
     required this.height,
     this.hasBorder=false,
     this.borderRadius=8,
     this.borderColor,
     this.isRectangle=true,
     this.shimmingColor=AppColors.primaryColor,
     this.baseColor=const Color(0xffD8D8D8),
     this.hasShadow=false,
     this.shadowColor=Colors.grey
   });



  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          borderRadius:isRectangle? BorderRadius.circular(14):null,
          shape: isRectangle?BoxShape.rectangle:BoxShape.circle,
          color: baseColor,
          border: hasBorder?Border.all(color: borderColor!,width: 2,):null,
        boxShadow: [
          if(hasShadow)
            BoxShadow(color: shadowColor!,offset:const Offset(0,5),blurRadius: 20)
        ]
      ),
      child: Shimmer.fromColors(
        highlightColor: shimmingColor!,
        baseColor:baseColor!,
        child: Container(
          width: width,
          height: height,

          decoration: BoxDecoration(
              borderRadius:isRectangle? BorderRadius.circular(14):null,
              shape: isRectangle?BoxShape.rectangle:BoxShape.circle,
              color: baseColor,
              border: hasBorder?Border.all(color: borderColor!,width: 2,):null
          ),
        ),
      ),
    );
  }
}


