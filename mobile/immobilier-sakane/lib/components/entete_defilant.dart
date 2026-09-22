import 'package:flutter/material.dart';

/// Une page dont l'en-tête — recherche, période, filtres — défile avec la
/// liste au lieu de rester figé en haut de l'écran. Il revient dès qu'on
/// remonte, sans devoir retourner tout en haut.
class PageAEnTeteDefilant extends StatelessWidget {
  final List<Widget> entete;
  final Widget corps;

  const PageAEnTeteDefilant({super.key, required this.entete, required this.corps});

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      floatHeaderSlivers: true,
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: entete,
          ),
        ),
      ],
      body: corps,
    );
  }
}
