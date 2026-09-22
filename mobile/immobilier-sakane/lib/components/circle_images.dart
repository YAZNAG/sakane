import 'package:flutter/material.dart';

import 'circle_image.dart';



class CircleImages extends StatelessWidget {

  List<String> images;
  //double width;
   double widthImage;


   CircleImages({
     required this.images,
     this.widthImage=40
   });

  @override
  Widget build(BuildContext context) {

    return Stack(
      children: [
        SizedBox(
          width: calculWidth(),
          height: widthImage,
        ),
        ...List.generate(getNbImages(),
                (index) {
                    return Positioned(
                        right:(widthImage/2)*index,
                        child: MyCircleImage(width: widthImage,url:images.elementAt(index))
                    );
                }
        )
      ],
    );
  }


  int getNbImages()=>images.length>=5?5:images.length;

  double calculWidth(){
    int nbImage=getNbImages();
    double totalWidth=widthImage+(nbImage-1)*(widthImage/2);
    return totalWidth;
  }

}
