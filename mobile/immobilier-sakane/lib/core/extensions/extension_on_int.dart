



import 'dart:ui';

import '../constants/app_colors.dart';



extension on_int on int{


  Color get color{
    Color color=AppColors.foregroundColor;
    switch(this){
      case 1:color=const Color(0xff0dcaf0);break;
      case 2:color=const Color(0xffffc107);break;
      case 3:color=const Color(0xff28a745);break;
      case 4:color=const Color(0xffdc3545);break;
      case 5:color=const Color(0xff3762D0);break;
    }
    return color;
  }

}