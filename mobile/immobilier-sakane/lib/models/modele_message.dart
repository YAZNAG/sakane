import 'package:flutter/material.dart';

/// Une modification apportée à un modèle de message.
class ModificationModele {
  final int? id;
  final String? contenuAvant;
  final String? contenuApres;
  final String? auteur;
  final DateTime? date;

  ModificationModele({
    this.id,
    this.contenuAvant,
    this.contenuApres,
    this.auteur,
    this.date,
  });

  factory ModificationModele.fromJson(Map<String, dynamic> json) {
    return ModificationModele(
      id: json['id'],
      contenuAvant: json['contenuAvant'],
      contenuApres: json['contenuApres'],
      auteur: json['auteur'],
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
    );
  }
}

/// Variable insérable dans un modèle, avec sa signification.
class VariableModele {
  final String variable;
  final String? libelle;
  final String? exemple;

  VariableModele({required this.variable, this.libelle, this.exemple});

  factory VariableModele.fromJson(Map<String, dynamic> json) {
    return VariableModele(
      variable: json['variable'] ?? '',
      libelle: json['libelle'],
      exemple: json['exemple'],
    );
  }
}

/// Texte d'une notification, modifiable par l'administrateur.
class ModeleMessage {
  final int? id;
  final String? code;
  final String? nom;
  final String? description;
  final String categorie;
  String? contenu;
  final String? defaut;

  /// Image jointe au message, envoyee en legende du texte.
  final String? image;
  final List<String> variables;
  final String langue;
  final bool actif;

  /// Vrai si le texte a été modifié par rapport à celui d'origine.
  final bool personnalise;

  final DateTime? modifieLe;
  final List<ModificationModele>? historique;

  ModeleMessage({
    this.id,
    this.code,
    this.nom,
    this.description,
    this.categorie = 'general',
    this.contenu,
    this.defaut,
    this.image,
    List<String>? variables,
    this.langue = 'fr',
    this.actif = true,
    this.personnalise = false,
    this.modifieLe,
    this.historique,
  }) : variables = variables ?? [];

  String get categorieLisible {
    switch (categorie) {
      case 'reservations':
        return 'Réservations';
      case 'nettoyage':
        return 'Nettoyage';
      case 'charges':
        return 'Charges';
      case 'reclamations':
        return 'Réclamations';
      case 'loyers':
        return 'Loyers';
      case 'rappels':
        return 'Rappels';
      case 'modifications':
        return 'Modifications de contrat';
      case 'general':
      case '':
        return 'Général';
      default:
        // Catégorie inconnue de l'application : on affiche son code.
        return categorie;
    }
  }

  /// Icône de la catégorie (section de la liste des modèles).
  IconData get categorieIcone {
    switch (categorie) {
      case 'reservations':
        return Icons.event_available_outlined;
      case 'nettoyage':
        return Icons.cleaning_services_outlined;
      case 'charges':
        return Icons.receipt_long_outlined;
      case 'reclamations':
        return Icons.report_problem_outlined;
      case 'loyers':
        return Icons.request_quote_outlined;
      case 'rappels':
        return Icons.alarm_outlined;
      case 'modifications':
        return Icons.edit_calendar;
      case 'general':
      case '':
        return Icons.chat_outlined;
      default:
        return Icons.label_outline;
    }
  }

  factory ModeleMessage.fromJson(Map<String, dynamic> json) {
    return ModeleMessage(
      id: json['id'],
      code: json['code'],
      nom: json['nom'],
      description: json['description'],
      categorie: json['categorie'] ?? 'general',
      contenu: json['contenu'],
      defaut: json['defaut'],
      image: json['image'],
      variables:
          (json['variables'] as List?)?.map((e) => e.toString()).toList() ?? [],
      langue: json['langue'] ?? 'fr',
      actif: json['actif'] ?? true,
      personnalise: json['personnalise'] ?? false,
      modifieLe:
          json['modifieLe'] != null ? DateTime.tryParse(json['modifieLe']) : null,
      historique: (json['historique'] as List?)
          ?.map((e) => ModificationModele.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Rendu du message avec des valeurs d'exemple.
class ApercuModele {
  final String apercu;

  /// Variables laissées sans valeur : souvent une faute de frappe.
  final List<String> inconnues;

  ApercuModele({this.apercu = '', List<String>? inconnues})
      : inconnues = inconnues ?? [];

  factory ApercuModele.fromJson(Map<String, dynamic> json) {
    return ApercuModele(
      apercu: json['apercu'] ?? '',
      inconnues:
          (json['inconnues'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
