import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/campagnes/commun/campagne_ui.dart';
import 'package:immobilier/features/campagnes/numero/cubit/numero_campagnes_cubit.dart';
import 'package:immobilier/models/numero_campagnes.dart';

/// Droit « Changer le numéro des campagnes ».
bool numeroCampagnesAutorise() => peut(AppPermission.manageCampaignNumber);

/// Ouvre la fiche « Numéro WhatsApp des campagnes » sur le cubit de
/// l'ecran appelant (la pastille de la liste suit donc les changements).
Future<void> ouvrirNumeroCampagnes(BuildContext context) {
  final cubit = context.read<NumeroCampagnesCubit>();
  if (cubit.state.numero == null && !cubit.state.enCours) cubit.charger();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const NumeroCampagnesSheet(),
    ),
  );
}

class NumeroCampagnesSheet extends StatefulWidget {
  const NumeroCampagnesSheet({super.key});

  @override
  State<NumeroCampagnesSheet> createState() => _NumeroCampagnesSheetState();
}

class _NumeroCampagnesSheetState extends State<NumeroCampagnesSheet> {
  final _cle = TextEditingController();
  bool _visible = false;
  String? _erreur;

  static const _aide =
      "Créez une nouvelle session dans Wasender, connectez le téléphone "
      "dédié en scannant le QR code, puis copiez la clé API de cette "
      "session ici. Les réservations, rappels et messages au syndic "
      "continuent d'utiliser le numéro principal.";

  @override
  void dispose() {
    _cle.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final cle = _cle.text.trim();
    if (cle.isEmpty) {
      setState(() => _erreur = "Collez la clé API de la session Wasender.");
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _erreur = null);
    final ok = await context.read<NumeroCampagnesCubit>().enregistrer(cle);
    if (ok && mounted) {
      // La cle complete ne reste jamais a l'ecran.
      _cle.clear();
      setState(() => _visible = false);
    }
  }

  Future<void> _revenir() async {
    final cubit = context.read<NumeroCampagnesCubit>();
    final ok = await confirmerCampagne(
      context,
      titre: "Revenir au numéro principal ?",
      message: "La clé de la session dédiée sera oubliée. Les prochains "
          "messages de campagne partiront du numéro principal.",
      confirmer: "Revenir",
      icone: Icons.undo_rounded,
      couleur: CampagneUi.orange,
    );
    if (ok) {
      setState(() => _erreur = null);
      await cubit.revenirAuPrincipal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bas = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bas),
      child: SafeArea(
        top: false,
        child: BlocConsumer<NumeroCampagnesCubit, NumeroCampagnesState>(
          listener: (context, state) {
            if (state.actionStatus == AppStatus.success) {
              showToast(state.message ?? "Opération effectuée", context,
                  second: 2);
            } else if (state.actionStatus == AppStatus.error) {
              setState(() => _erreur = state.error ?? "Erreur");
            }
          },
          builder: (context, state) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: CampagneUi.bordure,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.phone_android_rounded,
                        color: CampagneUi.vert, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text("Numéro WhatsApp des campagnes",
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: CampagneUi.texte)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _etat(context, state),
                const SizedBox(height: 14),
                const Text(_aide,
                    style: TextStyle(
                        fontSize: 13, height: 1.4, color: CampagneUi.gris)),
                const SizedBox(height: 16),
                TextField(
                  controller: _cle,
                  obscureText: !_visible,
                  enableSuggestions: false,
                  autocorrect: false,
                  enabled: !state.enCours,
                  onChanged: (_) {
                    if (_erreur != null) setState(() => _erreur = null);
                  },
                  onSubmitted: (_) => _enregistrer(),
                  decoration: InputDecoration(
                    labelText: "Clé API de la session Wasender",
                    errorText: _erreur,
                    errorMaxLines: 4,
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
                      tooltip: _visible ? "Masquer" : "Afficher",
                      icon: Icon(_visible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() => _visible = !_visible),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: state.enCours ? null : _enregistrer,
                    icon: state.enCours
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 20),
                    label: const Text("Enregistrer",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (state.numero?.dedie == true) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: state.enCours ? null : _revenir,
                      icon: const Icon(Icons.undo_rounded, size: 20),
                      label: const Text("Revenir au numéro principal"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CampagneUi.orange,
                        side: BorderSide(
                            color: CampagneUi.orange.withValues(alpha: .6)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _etat(BuildContext context, NumeroCampagnesState state) {
    final numero = state.numero;
    if (numero == null) {
      if (state.fetchStatus == AppStatus.error) {
        return Row(
          children: [
            const Icon(Icons.error_outline, color: CampagneUi.rouge, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  state.error ?? "Le numéro des campagnes n'a pas pu être chargé.",
                  style: const TextStyle(
                      fontSize: 13.5, color: CampagneUi.rouge)),
            ),
            TextButton(
              onPressed: () => context.read<NumeroCampagnesCubit>().charger(),
              child: const Text("Réessayer"),
            ),
          ],
        );
      }
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    final couleur = numero.dedie ? CampagneUi.vert : CampagneUi.bleu;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
              numero.dedie
                  ? Icons.verified_outlined
                  : Icons.info_outline_rounded,
              color: couleur,
              size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(numero.description,
                style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: couleur)),
          ),
        ],
      ),
    );
  }
}

/// Pastille de la liste : quel numero envoie les campagnes.
class NumeroCampagnesChip extends StatelessWidget {
  final NumeroCampagnes numero;
  final VoidCallback? onTap;

  const NumeroCampagnesChip({super.key, required this.numero, this.onTap});

  @override
  Widget build(BuildContext context) {
    final couleur = numero.dedie ? CampagneUi.vert : CampagneUi.gris;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ActionChip(
        onPressed: onTap,
        avatar: Icon(Icons.phone_android_rounded, size: 16, color: couleur),
        label: Text(numero.libelleCourt),
        labelStyle: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w600, color: couleur),
        backgroundColor: Colors.white,
        side: BorderSide(color: couleur.withValues(alpha: .45)),
        visualDensity: VisualDensity.compact,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
