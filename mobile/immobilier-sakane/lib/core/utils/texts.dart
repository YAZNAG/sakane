

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Widget title(String text,{double fontSize=18,Color color=Colors.black,FontWeight font=FontWeight.bold})=>Text(
    text,style: GoogleFonts.poppins(color: color,fontSize: fontSize,fontWeight: font),
);

Widget text(String text,{double fontSize=17,Color color=Colors.black54,FontWeight font=FontWeight.w600})=>Text(
  text,style: GoogleFonts.aBeeZee(color: color,fontSize: fontSize,fontWeight: font),
);
