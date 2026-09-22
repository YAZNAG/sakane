

import 'package:flutter/material.dart';

import '../../components/dialogue_infos.dart';


void showInfoDialogue(MessageUi messages,BuildContext context,void Function() onclick) {
  print("show dialogue");
  showDialog(context: context,
    builder: (context)=>DialogueInfos(message: messages,onclickAction:onclick),
  );
}

void hideDialogue(BuildContext context){
  Navigator.of(context,rootNavigator: true).pop();
}