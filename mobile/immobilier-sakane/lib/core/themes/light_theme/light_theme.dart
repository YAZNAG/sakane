



import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';

ThemeData lightTheme=ThemeData(

  // Sans palette declaree, Material 3 impose ses propres couleurs aux
  // dialogues, pastilles et interrupteurs. On part de la couleur de
  // l'application pour que tous les ecrans parlent le meme langage.
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primaryColor,
    primary: AppColors.primaryColor,
    secondary: AppColors.secondaryColor,
    brightness: Brightness.light,
  ),

  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    ),
    titleTextStyle: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
  ),

  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),

  cardTheme: CardThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),

  chipTheme: ChipThemeData(
    backgroundColor: Colors.white,
    selectedColor: AppColors.primaryColor,
    checkmarkColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    // Le texte d'une pastille se lit en noir : sans couleur declaree,
    // Material lui en donne une trop pale sur fond blanc.
    labelStyle: const TextStyle(fontSize: 12.5, color: Colors.black87),
    side: BorderSide(color: Colors.grey.shade300),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
  ),

  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primaryColor,
  ),

  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((etats) =>
        etats.contains(WidgetState.selected) ? Colors.white : null),
    trackColor: WidgetStateProperty.resolveWith((etats) =>
        etats.contains(WidgetState.selected) ? AppColors.primaryColor : null),
  ),

  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.primaryColor,
    foregroundColor: Colors.white,
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primaryColor,
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  ),


  textSelectionTheme: const TextSelectionThemeData(
      selectionColor: AppColors.primaryColor,
      selectionHandleColor: AppColors.primaryColor,
      cursorColor: AppColors.primaryColor
  ),
  timePickerTheme: TimePickerThemeData(
    backgroundColor: AppColors.scaffoldColor,
    hourMinuteShape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    hourMinuteTextColor: Colors.white,
    hourMinuteColor: AppColors.secondaryColor,
    dialHandColor: AppColors.secondaryColor,
    dialBackgroundColor: AppColors.secondaryColor.withOpacity(0.1),
    entryModeIconColor: AppColors.secondaryColor,
  ),
  datePickerTheme: DatePickerThemeData(
    backgroundColor: Colors.white,
    dayBackgroundColor:MaterialStateProperty.resolveWith((states){
      if(states.contains(MaterialState.selected)){
        return AppColors.secondaryColor;
      }
    }),
    dayStyle: GoogleFonts.acme(),
    headerHeadlineStyle: GoogleFonts.acme(),
    headerHelpStyle: GoogleFonts.acme(),
    rangePickerHeaderHeadlineStyle: GoogleFonts.acme(),
    rangePickerHeaderHelpStyle: GoogleFonts.acme(),
    yearBackgroundColor: MaterialStateProperty.resolveWith((states){
      if(states.contains(MaterialState.selected)){
        return AppColors.secondaryColor;
      }
    }),
    yearForegroundColor:  MaterialStateProperty.resolveWith((states){
      return Colors.black;
    }),
    yearStyle: GoogleFonts.acme(),
    headerBackgroundColor: AppColors.secondaryColor.withOpacity(0.5),
    headerForegroundColor: Colors.black,
    todayForegroundColor:MaterialStateProperty.resolveWith((states) => Colors.white),
    todayBackgroundColor: MaterialStateProperty.resolveWith((states){
      return AppColors.secondaryColor.withOpacity(0.5);
    }),
    weekdayStyle: GoogleFonts.acme(),
  ),
  textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.secondaryColor)
  ),

);



