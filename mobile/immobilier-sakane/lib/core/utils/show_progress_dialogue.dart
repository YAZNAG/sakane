import 'package:flutter/material.dart';

import '../../components/circle_progress_bar.dart';




void showProgressBar(BuildContext context) {
  showDialog(context: context,
    barrierDismissible: false,
    builder: (context) => MyCustomCircleBar(),
  );
}