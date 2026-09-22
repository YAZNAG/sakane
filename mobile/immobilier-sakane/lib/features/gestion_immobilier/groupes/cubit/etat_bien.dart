import 'package:flutter/material.dart';

/// État opérationnel d'un bien, tel qu'on le parcourt dans l'application.
enum EtatBien { tous, reserves, disponibles, nettoyage }

extension EtatBienLibelle on EtatBien {
  String get titre {
    switch (this) {
      case EtatBien.tous:
        return 'Tous les biens';
      case EtatBien.reserves:
        return 'Réservés';
      case EtatBien.disponibles:
        return 'Disponibles';
      case EtatBien.nettoyage:
        return 'Appartements en nettoyage';
    }
  }

  /// Code attendu par l'ecran par statut : available, reserved, cleaning.
  String get statut {
    switch (this) {
      case EtatBien.tous:
        return 'all';
      case EtatBien.reserves:
        return 'reserved';
      case EtatBien.disponibles:
        return 'available';
      case EtatBien.nettoyage:
        return 'cleaning';
    }
  }

  String get sousTitre {
    switch (this) {
      case EtatBien.tous:
        return "L'ensemble du parc, rangé par dossier";
      case EtatBien.reserves:
        return 'Occupés par un client';
      case EtatBien.disponibles:
        return 'Prêts à être loués';
      case EtatBien.nettoyage:
        return 'À nettoyer ou en cours';
    }
  }

  IconData get icone {
    switch (this) {
      case EtatBien.tous:
        return Icons.folder_copy_outlined;
      case EtatBien.reserves:
        return Icons.event_busy;
      case EtatBien.disponibles:
        return Icons.check_circle_outline;
      case EtatBien.nettoyage:
        return Icons.cleaning_services;
    }
  }

  List<Color> get degrade {
    switch (this) {
      case EtatBien.tous:
        return const [Color(0xFF3F51B5), Color(0xFF7E57C2)];
      case EtatBien.reserves:
        return const [Color(0xFFE53935), Color(0xFFFF7043)];
      case EtatBien.disponibles:
        return const [Color(0xFF2E7D32), Color(0xFF66BB6A)];
      case EtatBien.nettoyage:
        return const [Color(0xFFEF6C00), Color(0xFFFFB300)];
    }
  }
}
