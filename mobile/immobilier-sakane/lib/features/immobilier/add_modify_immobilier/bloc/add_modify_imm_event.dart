part of 'add_modify_imm_bloc.dart';

@immutable
abstract class AddModifyImmEvent {}




class FetchData extends AddModifyImmEvent{}





class SelectRegion extends AddModifyImmEvent {
  final Region region;
  final bool keepOld;
  SelectRegion(this.region,[this.keepOld=false]);
}

class UpdateRealestate extends AddModifyImmEvent{
  final Realestate realestate;

  UpdateRealestate(this.realestate);
}


class AddRealestate extends AddModifyImmEvent{}


class UpdateImmobilier extends AddModifyImmEvent{}


class AddOwner extends AddModifyImmEvent{
  final Owner owner;

  AddOwner(this.owner);
}

/// Creation d'un dossier depuis la fiche du bien.
class AddDossier extends AddModifyImmEvent {
  final String nom;

  AddDossier(this.nom);
}

class AddSecteur extends AddModifyImmEvent{
  final String nom;

  AddSecteur(this.nom);
}
