import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';

import 'package:immobilier/core/constants/app_colors.dart';



class SignaturePage extends StatefulWidget {
  const SignaturePage({Key? key}) : super(key: key);

  @override
  State<SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<SignaturePage> {

  final SignatureController _controller = SignatureController(
    penStrokeWidth: 5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    double width=MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Signature",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black,width: 1.5)
              ),
              child: Signature(
                controller: _controller,
                width: width,
                height: width,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10,),
            Row(
              children: [
                Expanded(
                    child:  ElevatedButton.icon(
                      icon: Icon(FontAwesomeIcons.check,color: Colors.white,),
                      onPressed:_validateSignature,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      label:Text(
                        "Confirmer",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    )
                ),
                const SizedBox(width: 6,),
                Expanded(
                    child:  ElevatedButton.icon(
                      icon: Icon(Icons.cancel_outlined,color: Colors.white,),
                      onPressed:_clearSignature,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade700,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      label:Text(
                        "Réinitialiser",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    )
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _clearSignature() {
    _controller.clear();
  }

  void _validateSignature() {
    GoRouter.of(context).pop(_controller.toPngBytes());
  }
}
