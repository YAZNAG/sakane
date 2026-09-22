import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../../components/form_field.dart';
import '../../../../../core/validator/validator.dart';
import 'package:immobilier/core/constants/app_colors.dart';



class ShrinkReservationDialog extends StatefulWidget {
  final DateTime originalCheckout;
  final double? originalPrice;
  final Function(DateTime newCheckout, double refundPrice) onConfirm;

  const ShrinkReservationDialog({
    Key? key,
    required this.originalCheckout,
    this.originalPrice,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<ShrinkReservationDialog> createState() => _ShrinkReservationDialogState();
}

class _ShrinkReservationDialogState extends State<ShrinkReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _refundPriceController;
  DateTime? selectedNewCheckout;
  late DateTime focusedDay;
  late DateTime today;
  late DateTime minDate;

  @override
  void initState() {
    super.initState();
    _refundPriceController = TextEditingController(text: "0");
    today = DateTime.now();

    // Strip time component for accurate date comparison
    today = DateTime(today.year, today.month, today.day);

    // Min date is today, max date is original checkout (inclusive)
    minDate = today;
    focusedDay = today;
  }

  @override
  void dispose() {
    _refundPriceController.dispose();
    super.dispose();
  }

  bool get canShrink {
    final originalCheckout = DateTime(
      widget.originalCheckout.year,
      widget.originalCheckout.month,
      widget.originalCheckout.day,
    );
    return !originalCheckout.isBefore(today);
  }

  int get nightsReduced {
    if (selectedNewCheckout == null) return 0;
    return widget.originalCheckout.difference(selectedNewCheckout!).inDays;
  }

  void _handleConfirm() {
    if (_formKey.currentState!.validate() && selectedNewCheckout != null) {
      widget.onConfirm(
        selectedNewCheckout!,
        double.parse(_refundPriceController.text),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    // If checkout is before today, show impossible message
    if (!canShrink) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade700,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Réduction impossible",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Impossible de réduire la réservation car la date de départ est déjà passée.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Fermer",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Icon(
            Icons.event_busy,
            color: AppColors.primaryColor,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Réduire la réservation",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCalendarSection(),
                const SizedBox(height: 16),
                if (selectedNewCheckout != null) _buildDetailsSection(),
                if (selectedNewCheckout != null) const SizedBox(height: 12),

              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            "Annuler",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: selectedNewCheckout == null ? null : _handleConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            "Réduire",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primaryColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Date de départ actuelle: ${widget.originalCheckout.formattedDateFr}",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MyFormField(
            label: "Montant du remboursement *",
            hint: "Entrez le montant à rembourser",
            labelColor: Colors.black,
            borderColor: Colors.black,
            hintColor: Colors.black54,
            activeBorderColor: Colors.black,
            controller: _refundPriceController,
            inputType: TextInputType.number,
            validator: Validator().required().number().make(),
            formatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChange: (value) {
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          TableCalendar<DateTime>(
            firstDay: minDate,
            lastDay: widget.originalCheckout,
            focusedDay: focusedDay,
            calendarFormat: CalendarFormat.month,
            selectedDayPredicate: (day) {
              return selectedNewCheckout != null &&
                  isSameDay(day, selectedNewCheckout);
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(color: Colors.red.shade600),
              selectedDecoration: BoxDecoration(
                color: Colors.green.shade700,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.primaryColor,
                shape: BoxShape.circle,
              ),
              disabledDecoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              disabledTextStyle: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            enabledDayPredicate: (day) {
              // Enable dates from today to original checkout (inclusive)
              return !day.isBefore(minDate) && !day.isAfter(widget.originalCheckout);
            },
            onDaySelected: (selectedDay, focused) {
              setState(() {
                selectedNewCheckout = selectedDay;
                focusedDay = focused;
              });
            },
            onPageChanged: (focused) {
              setState(() {
                focusedDay = focused;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Détails de la réduction",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.event_available, color: AppColors.primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                "Date originale: ${widget.originalCheckout.formattedDateFr}",
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.event_busy, color: AppColors.primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                "Nouvelle date: ${selectedNewCheckout!.formattedDateFr}",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }


}