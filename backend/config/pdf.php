<?php

/**
 * Polices des documents PDF.
 *
 * mPDF est lance avec « autoLangToFont » : pour un texte arabe, il
 * choisit lui-meme XBRiyaz et ignore le font-family demande. Redefinir
 * cette famille est donc le seul moyen fiable d'imposer une autre
 * police - la declarer sous un nouveau nom ne suffit pas.
 *
 * Traditional Arabic est celle du formulaire papier de l'agence. Son
 * champ fsType vaut 8 : l'editeur autorise l'incorporation dans un
 * document, ce que fait le PDF. Amiri, sous licence OFL, reste declaree
 * en solution de repli.
 */

$variablesPolices = (new Mpdf\Config\FontVariables())->getDefaults();
$variablesConfig  = (new Mpdf\Config\ConfigVariables())->getDefaults();

$arabe = [
    'R'          => 'TraditionalArabic-Regular.ttf',
    'B'          => 'TraditionalArabic-Bold.ttf',
    'useOTL'     => 0xFF,
    'useKashida' => 75,
];

$polices = $variablesPolices['fontdata'];

// La famille que mPDF choisit d'office pour l'arabe.
$polices['xbriyaz'] = $arabe;

// Et les deux noms explicites, pour pouvoir les demander en CSS.
$polices['traditionalarabic'] = $arabe;
$polices['amiri'] = [
    'R'          => 'Amiri-Regular.ttf',
    'B'          => 'Amiri-Bold.ttf',
    'useOTL'     => 0xFF,
    'useKashida' => 75,
];

return [
    'polices' => [
        'fontDir' => array_merge($variablesConfig['fontDir'], [
            resource_path('fonts'),
        ]),
        'fontdata' => $polices,
    ],
];
