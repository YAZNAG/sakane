import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/features/reception_whatsapp/cubit/reception_whatsapp_cubit.dart';
import 'package:immobilier/models/reception_whatsapp.dart';
import 'package:immobilier/routes.dart';

const Color couleurWhatsapp = Color(0xFF25D366);

/// Droit « Régler les messages de l'équipe » : régler la réception des
/// autres utilisateurs. Le serveur reste juge.
bool get estAdminReceptionWhatsapp => peut(AppPermission.manageTeamWhatsapp);

/// Ouvre les reglages de reception ([managerId] null : les miens).
Future<void> ouvrirReceptionWhatsapp(
  BuildContext context, {
  int? managerId,
  String? nom,
}) async {
  final uri = Uri(
    path: Routes.receptionWhatsapp,
    queryParameters: {
      if (managerId != null) 'manager': '$managerId',
      if ((nom ?? '').trim().isNotEmpty) 'nom': nom!.trim(),
    },
  );
  await GoRouter.of(context).push(uri.toString());
}

/// Tuile d'acces aux reglages, reprise sur les differents ecrans.
class TuileReceptionWhatsapp extends StatelessWidget {
  final String sousTitre;
  final VoidCallback onTap;

  const TuileReceptionWhatsapp({
    super.key,
    required this.sousTitre,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: couleurWhatsapp.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const FaIcon(
            FontAwesomeIcons.whatsapp,
            color: couleurWhatsapp,
            size: 20,
          ),
        ),
        title: const Text(
          'Réception WhatsApp',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          sousTitre,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class ReceptionWhatsappPage extends StatefulWidget {
  final int? managerId;
  final String? nom;

  const ReceptionWhatsappPage({super.key, this.managerId, this.nom});

  static Widget page({int? managerId, String? nom}) {
    return BlocProvider<ReceptionWhatsappCubit>(
      create: (ctx) => ReceptionWhatsappCubit(managerId: managerId)..charger(),
      child: ReceptionWhatsappPage(managerId: managerId, nom: nom),
    );
  }

  @override
  State<ReceptionWhatsappPage> createState() => _ReceptionWhatsappPageState();
}

class _ReceptionWhatsappPageState extends State<ReceptionWhatsappPage> {
  bool _afficherEnregistre = false;
  Timer? _minuteur;

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  void _signalerEnregistre() {
    _minuteur?.cancel();
    setState(() => _afficherEnregistre = true);
    _minuteur = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _afficherEnregistre = false);
    });
  }

  Future<void> _apresBascule(Future<String?> action) async {
    final erreur = await action;
    if (erreur == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(erreur), backgroundColor: Colors.red.shade700),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Réception WhatsApp',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: BlocConsumer<ReceptionWhatsappCubit, ReceptionWhatsappState>(
        listenWhen: (a, b) => a.enregistreLe != b.enregistreLe,
        listener: (context, state) => _signalerEnregistre(),
        builder: (context, state) {
          if (state.statut == AppStatus.error) {
            return _Erreur(
              message: state.error ?? "Une erreur s'est produite",
              onReessayer: () =>
                  context.read<ReceptionWhatsappCubit>().charger(),
            );
          }
          final reglages = state.reglages;
          if (state.statut != AppStatus.success || reglages == null) {
            return Center(child: MyLoadingIndicator());
          }
          return _contenu(context, state, reglages);
        },
      ),
    );
  }

  Widget _contenu(
    BuildContext context,
    ReceptionWhatsappState state,
    ReceptionWhatsapp r,
  ) {
    final cubit = context.read<ReceptionWhatsappCubit>();
    final nom = (widget.nom ?? '').trim().isNotEmpty
        ? widget.nom!.trim()
        : (r.nom ?? '').trim();
    final pourMoi = widget.managerId == null;
    final qui = pourMoi
        ? 'que vous recevez'
        : 'que ${nom.isEmpty ? 'cet utilisateur' : nom} reçoit';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Carte(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: couleurWhatsapp,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pourMoi || nom.isEmpty ? 'Messages WhatsApp' : nom,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _Etat(
                    enCours: state.enCours > 0,
                    enregistre: _afficherEnregistre,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Choisissez les messages WhatsApp $qui. '
                'Les messages envoyés aux clients ne sont pas concernés.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 14),
              if (r.sansNumero)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aucun numéro : aucun message ne peut être reçu',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 18,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      r.telephone!.trim(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Carte(
          padding: EdgeInsets.zero,
          child: SwitchListTile(
            value: r.actif,
            onChanged: (v) => _apresBascule(cubit.basculerTout(v)),
            activeTrackColor: couleurWhatsapp,
            title: const Text(
              'Recevoir les messages WhatsApp',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              r.actif
                  ? 'Selon les types choisis ci-dessous'
                  : 'Aucun message n\'est reçu',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (r.types.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Types de messages',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        for (final section in r.sections) ...[
          _section(cubit, r, section),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  /// Un groupe : en-tête avec une bascule pour tout le groupe, puis une
  /// bascule par type de message.
  Widget _section(
    ReceptionWhatsappCubit cubit,
    ReceptionWhatsapp r,
    SectionReceptionWhatsapp section,
  ) {
    final recus = section.nombreRecus;
    final total = section.types.length;
    return _Carte(
      padding: EdgeInsets.zero,
      child: Opacity(
        opacity: r.actif ? 1 : .5,
        child: Column(
          children: [
            Container(
              color: couleurWhatsapp.withValues(alpha: .06),
              child: SwitchListTile(
                value: section.toutRecu,
                onChanged: r.actif
                    ? (v) => _apresBascule(cubit.basculerGroupe(section.code, v))
                    : null,
                activeTrackColor: couleurWhatsapp,
                title: Text(
                  section.libelle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  recus == total
                      ? 'Tout est reçu'
                      : recus == 0
                          ? "Rien n'est reçu"
                          : '$recus sur $total reçu${recus > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ),
            for (final type in section.types) ...[
              Divider(height: 1, color: Colors.grey.shade200),
              SwitchListTile(
                value: type.actif,
                onChanged: r.actif
                    ? (v) => _apresBascule(cubit.basculerType(type.code, v))
                    : null,
                activeTrackColor: couleurWhatsapp,
                contentPadding: const EdgeInsets.only(left: 28, right: 16),
                title: Text(
                  type.libelle,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: type.description.isEmpty
                    ? null
                    : Text(
                        type.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Etat extends StatelessWidget {
  final bool enCours;
  final bool enregistre;

  const _Etat({required this.enCours, required this.enregistre});

  @override
  Widget build(BuildContext context) {
    if (enCours) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.grey.shade500,
        ),
      );
    }
    return AnimatedOpacity(
      opacity: enregistre ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 4),
          Text(
            'Enregistré',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Carte({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Erreur extends StatelessWidget {
  final String message;
  final VoidCallback onReessayer;

  const _Erreur({required this.message, required this.onReessayer});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade700),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onReessayer,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
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
}

/// Vue d'ensemble pour l'administrateur : qui recoit quoi.
class ReceptionsWhatsappPage extends StatelessWidget {
  const ReceptionsWhatsappPage({super.key});

  static Widget page() {
    return BlocProvider<ReceptionsWhatsappCubit>(
      create: (ctx) => ReceptionsWhatsappCubit()..charger(),
      child: const ReceptionsWhatsappPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Réception WhatsApp',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ReceptionsWhatsappCubit>().charger(),
          ),
        ],
      ),
      body: BlocBuilder<ReceptionsWhatsappCubit, ReceptionsWhatsappState>(
        builder: (context, state) {
          final cubit = context.read<ReceptionsWhatsappCubit>();
          if (state.statut == AppStatus.error) {
            return _Erreur(
              message: state.error ?? "Une erreur s'est produite",
              onReessayer: cubit.charger,
            );
          }
          final liste = state.liste;
          if (state.statut != AppStatus.success || liste == null) {
            return Center(child: MyLoadingIndicator());
          }
          if (liste.isEmpty) {
            return Center(
              child: Text(
                'Aucun utilisateur',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => cubit.charger(silencieux: true),
            color: AppColors.primaryColor,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: liste.length + 1,
              separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 12 : 8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Text(
                    'Messages WhatsApp reçus par chaque utilisateur. '
                    'Les messages envoyés aux clients ne sont pas concernés.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  );
                }
                return _LigneUtilisateur(
                  reglages: liste[i - 1],
                  onTap: () async {
                    final r = liste[i - 1];
                    if (r.managerId == null) return;
                    await ouvrirReceptionWhatsapp(
                      context,
                      managerId: r.managerId,
                      nom: r.nom,
                    );
                    cubit.charger(silencieux: true);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _LigneUtilisateur extends StatelessWidget {
  final ReceptionWhatsapp reglages;
  final VoidCallback onTap;

  const _LigneUtilisateur({required this.reglages, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = reglages;
    final nom = (r.nom ?? '').trim().isEmpty
        ? 'Utilisateur ${r.managerId ?? ''}'
        : r.nom!.trim();
    final resume = r.resume;
    // Groupes coupés en tout ou partie (seulement si la réception est active).
    final coupes = !r.actif
        ? const <String>[]
        : [
            for (final s in r.sections)
              if (s.nombreRecus == 0)
                s.libelle
              else if (s.nombreRecus < s.types.length)
                '${s.libelle} (${s.types.length - s.nombreRecus})',
          ];
    final Color teinte;
    if (resume == 'Tout reçu') {
      teinte = Colors.green.shade700;
    } else if (resume == 'Rien') {
      teinte = Colors.red.shade700;
    } else {
      teinte = Colors.orange.shade800;
    }

    return _Carte(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        title: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.sansNumero ? 'Aucun numéro' : r.telephone!.trim(),
              style: TextStyle(
                fontSize: 12,
                color: r.sansNumero
                    ? Colors.orange.shade900
                    : Colors.grey.shade600,
              ),
            ),
            if (coupes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Coupé : ${coupes.join(', ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: teinte.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                resume,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: teinte,
                ),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
