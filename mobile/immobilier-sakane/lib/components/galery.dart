import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'shimming_widget.dart';



class Galery extends StatelessWidget {

  List<String> images;

  void Function(String)? onImageClick;

  Galery({required this.images,this.onImageClick});

  @override
  Widget build(BuildContext context) {
    double width=MediaQuery.sizeOf(context).width;
    return SizedBox(
      height:130 ,
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(left: 12.0),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            ...List.generate(images.length, (index) =>image(images!.elementAt(index)) ),

          ],
        ),
      ),
    );
  }


  Widget image(String image){
    return GestureDetector(
      onTap: ()=>onImageClick?.call(image),
      child: Container(

        margin: EdgeInsets.symmetric(horizontal: 8,vertical: 5),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: CachedNetworkImage(
          width: 120,
          height: 130,
          fit: BoxFit.cover,
          imageUrl: image,
          placeholder: (context,str){
            return ShimmingWidget(width: 120, height: 130,borderRadius: 8);
          },
        )
      ),
    );
  }





}
