import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';

class InfoItem extends StatelessWidget {
  String? name;
  String? value;
  Color? colorName;
  Color? colorValue;

   InfoItem({this.name,this.value,this.colorName=Colors.black,this.colorValue=AppColors.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$name",
            style: GoogleFonts.acme(
                color: colorName, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 20,),
          Expanded(
              child: Text(
                "${value??'-'}",
                textAlign: TextAlign.right,
                style: GoogleFonts.acme(
                    color: colorValue, fontSize: 17, fontWeight: FontWeight.bold),
              )),
        ],
      ),
    );
  }
}


