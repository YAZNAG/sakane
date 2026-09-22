import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';





class MyTextButton extends StatelessWidget {
  List<String> parts;
  List<Color> colors;
  Color? iconColor;
  IconData? icon;

  void Function()? onclick;

  MyTextButton({required this.parts,required this.colors,this.icon,this.onclick,this.iconColor}){
    assert(parts.isNotEmpty && colors.isNotEmpty && colors.length==parts.length);
  }

  @override
  Widget build(BuildContext context) {
    return icon!=null
        ?TextButton.icon(onPressed:()=>onclick?.call(), icon:Icon(icon,color: colors.first,) , label:_getText())
        :TextButton(onPressed: ()=>onclick?.call(), child: _getText());
  }

  Widget _getText(){
    List<String> rest=parts.length>1?parts.sublist(1):[];
    List<Color> restColors=colors.length>1?colors.sublist(1):[];

    return Text.rich(
      TextSpan(text:parts.elementAt(0),
          style: GoogleFonts.aBeeZee(color:colors.elementAt(0),),
        children: List.generate(rest.length, (index) => TextSpan(text: rest.elementAt(index),style: GoogleFonts.aBeeZee(color:restColors.elementAt(index))))
      ),
      style: GoogleFonts.aBeeZee(color: colors[0]),);
  }
}
