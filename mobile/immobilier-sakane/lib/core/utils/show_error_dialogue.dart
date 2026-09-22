

import 'package:flutter/material.dart';
import 'package:immobilier/components/validation_error.dart';

void showDialogueError(context,Map<String,dynamic>errors){
  showDialog(
      context: context,
      builder: (ctx)=>ValidationErrorWidget(error: errors)
  );
}