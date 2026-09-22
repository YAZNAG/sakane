import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';



class MyDropDownList extends StatelessWidget {
  Map<String,dynamic> data;
  Color color;
  dynamic currentValue;
  void Function(dynamic)? onSelect;
  dynamic firstSelectedValue;
  String label;
  bool isWithLable;

  MyDropDownList({this.isWithLable=true,required this.currentValue,required this.data,this.firstSelectedValue="null",this.label="Tous",this.onSelect,this.color=AppColors.primaryColor});

  @override
  Widget build(BuildContext context) {
    double width=MediaQuery.sizeOf(context).width;
    double height=MediaQuery.sizeOf(context).height;
    return  ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 400
      ),
      child: DropdownMenu(
        menuHeight: height*0.6,
        width: width*0.8,
        onSelected: onSelect,
        initialSelection: currentValue,
        dropdownMenuEntries:[
          if(isWithLable)
          DropdownMenuEntry(value: firstSelectedValue, label: label),
          ...(data.keys.map((key) => DropdownMenuEntry(value: data[key], label: key)).toList())
        ],
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: color,width: 1.5)
          ),
          activeIndicatorBorder: BorderSide(color: color,width: 1.5),
          enabledBorder:  OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: color,width: 1.5)
          ),
          focusedBorder:  OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: color,width: 1.5)
          ),
        ),
      ),
    );
  }
}





