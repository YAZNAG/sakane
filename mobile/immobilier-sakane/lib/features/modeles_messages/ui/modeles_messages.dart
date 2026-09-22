import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/features/modeles_messages/cubit/modeles_messages_cubit.dart';
import 'package:immobilier/features/modeles_messages/ui/edition_modele.dart';
import 'package:immobilier/models/modele_message.dart';

/// Liste des messages automatiques, regroupés par domaine.
class ModelesMessagesPage extends StatelessWidget {
  const ModelesMessagesPage({super.key});

  static Widget page() => BlocProvider(
        create: (_) => ModelesMessagesCubit()..charger(),
        child: const ModelesMessagesPage(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Modèles de messages'),
        centerTitle: true,
      ),
      body: BlocBuilder<ModelesMessagesCubit, ModelesMessagesState>(
        builder: (context, state) {
          if (state.fetchStatus == AppStatus.loading) {
            return Center(child: MyLoadingIndicator());
          }
          if (state.fetchStatus == AppStatus.error) {
            return MyErrorWidget(
              error: state.error ?? "Erreur",
              action: AppStrings.tryAgain,
              actionCLick: () => context.read<ModelesMessagesCubit>().charger(),
            );
          }

          final groupes = state.parCategorie;
          if (groupes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  "Aucun modèle n'est encore installé sur le serveur.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<ModelesMessagesCubit>().charger(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 26),
              children: [
                _avertissement(),
                const SizedBox(height: 14),
                ...groupes.entries.expand((groupe) => [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
                        child: Row(
                          children: [
                            Icon(groupe.value.first.categorieIcone,
                                size: 17, color: Colors.grey.shade700),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                groupe.key,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Text(
                              '${groupe.value.length}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      ...groupe.value.map((m) => _carte(context, m)),
                    ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _avertissement() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade800),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              "Ces textes partent automatiquement aux clients et à l'équipe. "
              "Vous pouvez les modifier ; le texte d'origine reste disponible "
              "à tout moment.",
              style: TextStyle(
                  fontSize: 12.5, color: Colors.blue.shade900, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carte(BuildContext context, ModeleMessage m) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
        title: Row(
          children: [
            Expanded(
              child: Text(
                m.nom ?? m.code ?? '',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
            if (!m.actif)
              _etiquette("Désactivé", Colors.grey.shade600)
            else if (m.personnalise)
              _etiquette("Modifié", Colors.orange.shade700),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            m.description ?? m.contenu ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: Colors.black87),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {
          final cubit = context.read<ModelesMessagesCubit>();
          if (m.id == null) return;
          cubit.ouvrir(m.id!);
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: cubit,
              child: EditionModelePage(modele: m),
            ),
          ));
        },
      ),
    );
  }

  Widget _etiquette(String texte, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texte,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: couleur),
      ),
    );
  }
}

/// Couleur d'accent réutilisée par l'écran d'édition.
Color get couleurModeles => AppColors.primaryColor;
