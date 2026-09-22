import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:signature/signature.dart';

/// Le contrat, lu dans l'application.
///
/// Il s'ouvrait jusqu'ici dans un lecteur externe : l'agent quittait
/// l'application, et devait y revenir à la main pour faire signer. Le
/// document se lit désormais sur place, et la signature se recueille
/// dans la foulée.
class VisionneuseContrat extends StatefulWidget {
  final String chemin;
  final String titre;

  /// Proposer la signature. Le paraphe recueilli est renvoyé à
  /// l'appelant, qui décide seul de ce qu'il en fait.
  final bool avecSignature;

  /// Une action proposée sous le document — envoyer la facture, par
  /// exemple. Elle n'apparaît qu'une fois la pièce sous les yeux.
  final Widget? actionBas;

  const VisionneuseContrat({
    super.key,
    required this.chemin,
    this.titre = "Contrat",
    this.avecSignature = false,
    this.actionBas,
  });

  /// Ouvre la visionneuse et retourne le paraphe, ou null.
  static Future<Uint8List?> ouvrir(
    BuildContext context, {
    required String chemin,
    String titre = "Contrat",
    bool avecSignature = false,
    Widget? actionBas,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => VisionneuseContrat(
          chemin: chemin,
          titre: titre,
          avecSignature: avecSignature,
          actionBas: actionBas,
        ),
      ),
    );
  }

  @override
  State<VisionneuseContrat> createState() => _VisionneuseContratState();
}

class _VisionneuseContratState extends State<VisionneuseContrat> {
  int _page = 0;
  int _pages = 0;
  String? _erreur;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF37474F),
      appBar: AppBar(
        title: Text(
          widget.titre,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        actions: [
          IconButton(
            tooltip: "Partager",
            onPressed: () => SharePlus.instance.share(
              ShareParams(files: [XFile(widget.chemin)], subject: widget.titre),
            ),
            icon: const Icon(Icons.share, color: Colors.white),
          ),
          IconButton(
            tooltip: "Ouvrir hors de l'application",
            onPressed: () => OpenFile.open(widget.chemin),
            icon: const Icon(Icons.open_in_new, color: Colors.white),
          ),
        ],
      ),
      body: _erreur != null ? _messageErreur() : _document(),
      bottomNavigationBar: _erreur != null
          ? null
          : widget.avecSignature
              ? _barreSignature()
              : widget.actionBas,
    );
  }

  Widget _document() {
    return Stack(
      children: [
        PDFView(
          filePath: widget.chemin,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: false,
          fitPolicy: FitPolicy.WIDTH,
          onRender: (pages) => setState(() => _pages = pages ?? 0),
          onPageChanged: (page, _) => setState(() => _page = page ?? 0),
          onError: (e) => setState(() => _erreur = e.toString()),
        ),
        if (_pages > 1)
          Positioned(
            right: 14,
            bottom: 14,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .62),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${_page + 1} / $_pages",
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _messageErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf_outlined,
                size: 54, color: Colors.white54),
            const SizedBox(height: 14),
            const Text(
              "Ce document ne s'affiche pas ici",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              "Vous pouvez l'ouvrir avec une autre application.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13.5),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => OpenFile.open(widget.chemin),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text("Ouvrir"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barreSignature() {
    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Présentez le document au client, puis recueillez sa signature.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _signer,
                icon: const Icon(Icons.draw_outlined, size: 19),
                label: const Text("Signer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signer() async {
    final paraphe = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const _PaveSignature(),
    );

    if (paraphe != null && mounted) {
      Navigator.of(context).pop(paraphe);
    }
  }
}

/// Le pavé où le client trace son paraphe.
class _PaveSignature extends StatefulWidget {
  const _PaveSignature();

  @override
  State<_PaveSignature> createState() => _PaveSignatureState();
}

class _PaveSignatureState extends State<_PaveSignature> {
  final SignatureController _controleur = SignatureController(
    penStrokeWidth: 4,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final largeur = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Signature du client",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400, width: 1.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Signature(
              controller: _controleur,
              width: largeur - 32,
              height: 210,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _controleur.clear,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("Effacer"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _valider,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text("Valider"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _valider() async {
    if (_controleur.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le client n'a pas encore signé.")),
      );
      return;
    }

    final octets = await _controleur.toPngBytes();
    if (octets != null && mounted) {
      Navigator.of(context).pop(octets);
    }
  }
}

/// Vrai lorsque le fichier existe et n'est pas vide : un PDF tronqué
/// afficherait une page blanche sans expliquer pourquoi.
bool contratLisible(String chemin) {
  final fichier = File(chemin);
  return fichier.existsSync() && fichier.lengthSync() > 0;
}
