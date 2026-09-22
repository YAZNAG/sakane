import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../../components/form_field.dart';
import '../../../../../core/validator/validator.dart';
import 'package:immobilier/core/constants/app_colors.dart';



class ProlongerReservationDialog extends StatefulWidget {
  final DateTime from;
  final DateTime maxDate;
  final double? initialPrice;
  final Function(DateTime checkout, double price) onConfirm;

  const ProlongerReservationDialog({
    Key? key,
    required this.from,
    required this.maxDate,
    this.initialPrice,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<ProlongerReservationDialog> createState() => _ProlongerReservationDialogState();
}

class _ProlongerReservationDialogState extends State<ProlongerReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;

  DateTime? selectedCheckout;
  late DateTime focusedDay;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.initialPrice?.toString() ?? "0",
    );
    focusedDay = widget.from;
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  int get nights {
    return selectedCheckout != null
        ? selectedCheckout!.difference(widget.from).inDays
        : 0;
  }

  String get totalPrice {
    if (_priceController.text.isNotEmpty && nights > 0) {
      return (double.parse(_priceController.text) * nights).toStringAsFixed(2);
    }
    return "0.00";
  }

  void _handleConfirm() {
    if (_formKey.currentState!.validate() && selectedCheckout != null) {
      widget.onConfirm(
        selectedCheckout!,
        double.parse(_priceController.text),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Icon(
            Icons.calendar_month,
            color: AppColors.primaryColor,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Prolonger la réservation",
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
                if (selectedCheckout != null) _buildDetailsSection(),
                const SizedBox(height: 12),
                _buildTotalPriceSection(),
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
          onPressed: selectedCheckout == null ? null : _handleConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            "Prolonger",
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
          MyFormField(
            label: "Prix par nuit *",
            hint: "Entrez le prix par nuit",
            labelColor: Colors.black,
            borderColor: Colors.black,
            hintColor: Colors.black54,
            activeBorderColor: Colors.black,
            controller: _priceController,
            inputType: TextInputType.number,
            validator: Validator().required().number().make(),
            formatters: [FilteringTextInputFormatter.digitsOnly],
            onChange: (value) {
              setState(() {}); // Rebuild to update total price
            },
          ),
          const SizedBox(height: 16),
          TableCalendar<DateTime>(
            firstDay: widget.from,
            lastDay: widget.maxDate,
            focusedDay: focusedDay,
            calendarFormat: CalendarFormat.month,
            selectedDayPredicate: (day) {
              return selectedCheckout != null &&
                  isSameDay(day, selectedCheckout);
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
              final dayAfterCheckout = widget.from.add(const Duration(days: 1));
              return !day.isBefore(dayAfterCheckout) && day.isBefore(widget.maxDate);
            },
            onDaySelected: (selectedDay, focused) {
              setState(() {
                selectedCheckout = selectedDay;
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
            "Détails de la prolongation",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.login, color: AppColors.primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                "Début: ${widget.from.formattedDateFr}",
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.logout, color: AppColors.primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                "Fin: ${selectedCheckout!.formattedDateFr}",
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.nights_stay, color: AppColors.primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                "$nights nuit${nights > 1 ? 's' : ''}",
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

  Widget _buildTotalPriceSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.monetization_on,
                color: Colors.green.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                "Prix total:",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          Text(
            "$totalPrice MAD",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}