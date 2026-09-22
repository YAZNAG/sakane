import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/booking.dart';
import 'package:immobilier/repository/repository.dart';

/// Envoie le contrat de location au syndic (union des propriétaires) par
/// WhatsApp. Le numéro et le message sont proposés depuis les réglages de
/// l'agence et restent modifiables avant l'envoi.
Future<void> partagerAvecSyndic(BuildContext context, Booking booking) async {
  final messager = ScaffoldMessenger.of(context);
  if (booking.id == null) return;

  Map<String, dynamic> reglages;
  try {
    reglages = await Dependencies.get<Repository>().reglagesSyndic(bookingId: booking.id);
  } catch (_) {
    messager.showSnackBar(const SnackBar(
        content: Text("Les réglages du syndic n'ont pas pu être chargés. Vérifiez la connexion.")));
    return;
  }
  if (!context.mounted) return;

  final envoye = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogueSyndic(booking: booking, reglages: reglages),
  );

  if (envoye != null) {
    messager.showSnackBar(SnackBar(
      content: Text('Contrat envoyé au syndic ($envoye).'),
      duration: const Duration(seconds: 5),
    ));
  }
}

class _DialogueSyndic extends StatefulWidget {
  final Booking booking;
  final Map<String, dynamic> reglages;

  const _DialogueSyndic({required this.booking, required this.reglages});

  @override
  State<_DialogueSyndic> createState() => _DialogueSyndicState();
}

class _DialogueSyndicState extends State<_DialogueSyndic> {
  late final TextEditingController _telephone;
  late final TextEditingController _message;
  bool _garder = true;
  bool _enCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _telephone = TextEditingController(text: (widget.reglages['telephone'] ?? '').toString());
    _message = TextEditingController(text: (widget.reglages['message'] ?? '').toString());
  }

  @override
  void dispose() {
    _telephone.dispose();
    _message.dispose();
    super.dispose();
  }

  void _insererVariable(String v) {
    final sel = _message.selection;
    final texte = _message.text;
    final debut = sel.isValid ? sel.start : texte.length;
    final fin = sel.isValid ? sel.end : texte.length;
    final nouveau = texte.replaceRange(debut, fin, v);
    _message.value = TextEditingValue(
      text: nouveau,
      selection: TextSelection.collapsed(offset: debut + v.length),
    );
  }

  Future<void> _envoyer() async {
    final tel = _telephone.text.replaceAll(RegExp(r'\D'), '');
    if (tel.length < 10 || tel.startsWith('0')) {
      setState(() => _erreur = 'Écrivez le numéro au format international, par exemple 212612345678.');
      return;
    }
    if (_message.text.trim().isEmpty) {
      setState(() => _erreur = 'Écrivez le message qui accompagne le contrat.');
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final envoyeA = await Dependencies.get<Repository>().partagerContratSyndic(
        widget.booking.id!,
        telephone: tel,
        message: _message.text,
        enregistrer: _garder,
      );
      if (mounted) Navigator.of(context).pop(envoyeA);
    } catch (ex) {
      if (mounted) {
        setState(() {
          _enCours = false;
          _erreur = ex.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final variables = ((widget.reglages['variables'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final bien = widget.booking.realestate?.title;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      title: Row(
        children: [
          Icon(Icons.apartment, color: AppColors.primaryColor),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Envoyer le contrat au syndic',
                style: TextStyle(fontSize: 17, color: Color(0xFF17262E))),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((bien ?? '').isNotEmpty)
              Text('Contrat public de « $bien »',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7B84))),
            const SizedBox(height: 12),
            TextField(
              controller: _telephone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Numéro WhatsApp du syndic',
                hintText: '212612345678',
                helperText: 'Format international, sans le 0 du début.',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              style: const TextStyle(color: Colors.black87, fontSize: 13.5),
              decoration: InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (variables.isNotEmpty) ...[
              const Text('Insérer :', style: TextStyle(fontSize: 12, color: Color(0xFF6B7B84))),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: variables
                    .map((v) => ActionChip(
                          label: Text(v, style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _insererVariable(v),
                        ))
                    .toList(),
              ),
            ],
            CheckboxListTile(
              value: _garder,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Garder ce numéro et ce message par défaut',
                  style: TextStyle(fontSize: 13, color: Color(0xFF17262E))),
              onChanged: (v) => setState(() => _garder = v ?? false),
            ),
            if (_erreur != null)
              Text(_erreur!, style: TextStyle(fontSize: 12.5, color: Colors.red.shade700)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enCours ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _enCours ? null : _envoyer,
          icon: _enCours
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, size: 18),
          label: const Text('Envoyer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
