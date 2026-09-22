import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/config.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/offline/synchronisation.dart';
import 'package:immobilier/core/services/shared_pref_service.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/repository/data_providers/api/api_client.dart';
import 'package:immobilier/repository/repository.dart';


import 'core/themes/light_theme/light_theme.dart';
import 'routes.dart';

void main()async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.dark
    )
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitDown,
    DeviceOrientation.portraitUp
  ]);
  await prepareDependencies();
  runApp(const MyApp());
}

Future<void> prepareDependencies()async{
  SharedPrefService sharedPrefService=await SharedPrefService.initializeService();
  String token=sharedPrefService.getValue(SharedPrefService.token, "");
  ApiClient apiClient=ApiClient(baseUrl: baseUrl,token: token,apiAppsVersion: baseUrlApiVersion);
  Repository repository=Repository(apiClient: apiClient);
  Dependencies.put(repository);
  Dependencies.put(sharedPrefService);

  // Surveille la connexion et envoie les operations mises de cote
  // pendant les coupures.
  await Synchronisation.instance.demarrer(apiClient.dio);
  Synchronisation.instance.fournisseurContexte =
      () => Routes.router.routerDelegate.navigatorKey.currentContext;
  //await test();
}

Future<void> test()async{
  Repository repository=Dependencies.get<Repository>();
 final bookings=await repository.fetchBookings("2025-01-30", "2025-10-10",type: "realworld");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: MaterialApp.router(
        title: 'Immobilier',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        routerConfig: Routes.router,
        // L'application parle français : calendriers, sélecteurs de date
        // et boutons des dialogues, avec les dates en jour/mois/année.
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}


