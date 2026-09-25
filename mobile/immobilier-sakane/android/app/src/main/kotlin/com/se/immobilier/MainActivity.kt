package com.se.immobilier

import io.flutter.embedding.android.FlutterFragmentActivity

// La fenetre de biometrie (local_auth) est un fragment : elle exige une
// activite capable d'en heberger un. Sans cela, le deverrouillage par
// empreinte ou par visage echoue au lancement.
class MainActivity : FlutterFragmentActivity()
