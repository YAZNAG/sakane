


import 'dart:ui';

extension ext_for_color on String{


  Color get toColor {
    String str = replaceAll("#", "").toUpperCase();
    if (str.length == 6) {
      str = "FF$str";
    }
    return Color(int.parse(str, radix: 16));
  }

}