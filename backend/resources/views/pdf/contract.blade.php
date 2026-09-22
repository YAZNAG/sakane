@php
    /**
     * Fiche de renseignements ALWED LH.
     *
     * Reprend le formulaire papier de l'agence : meme en-tete, meme
     * cadre filigrane, memes pastilles bilingues, meme pied de page.
     * Ce qui est connu de la reservation remplit les pointilles ; ce qui
     * manque les laisse vides, pour etre complete a la main comme avant.
     */

    // La teinte du logo, relevee sur le document d'origine.
    $couleur = '#43B2BC';
    $ardoise = '#697274';

    $dossierMarque = resource_path('views/pdf/assets');

    // L'en-tete horizontal de l'agence. A defaut, le logo du compte.
    $marque = null;
    $fichierMarque = $dossierMarque . '/alwed-marque.png';
    if (is_file($fichierMarque)) {
        $marque = 'data:image/png;base64,' . base64_encode(file_get_contents($fichierMarque));
    }

    // Le filigrane est passe par son chemin : mPDF lit un fond depuis le
    // disque, la ou une image encodee ne passerait pas toujours.
    $fichierFiligrane = $dossierMarque . '/alwed-filigrane.png';
    $filigrane = is_file($fichierFiligrane) ? $fichierFiligrane : null;

    $client = $booking->client;
    $bien = $booking->realestate;

    $date = function ($valeur, $format = 'd/m/Y') {
        if (empty($valeur)) return '';
        try {
            return $valeur instanceof \DateTimeInterface
                ? \Carbon\Carbon::instance($valeur)->format($format)
                : \Carbon\Carbon::parse((string) $valeur)->format($format);
        } catch (\Throwable $e) {
            return '';
        }
    };

    $nuits = (int) ($booking->nb_days ?? 0);
    $duree = $nuits > 0 ? $nuits . ' night' . ($nuits > 1 ? 's' : '') : '';

    // Le nom arabe du client, lorsqu'il a ete saisi ou lu sur la CIN.
    $prenomAr = trim((string) ($client->first_name_ar ?? ''));
    $nomAr    = trim((string) ($client->last_name_ar ?? ''));

    $adresseBien = trim(($bien->address ?? '') . ' ' . ($bien->city->name ?? ''));
    if ($adresseBien === '') {
        $adresseBien = (string) ($bien->title ?? '');
    }

    $telephone = \App\Services\Telephone::local($client->tel ?? '');

    $qrImage = null;
    if (!empty($qrContenu)) {
        try {
            $qr = new \Mpdf\QrCode\QrCode($qrContenu, 'M');
            $qrImage = 'data:image/png;base64,' . base64_encode(
                (new \Mpdf\QrCode\Output\Png())->output($qr, 260)
            );
        } catch (\Throwable $e) {
            // Sans code QR, la fiche reste valable : on n'echoue pas pour si peu.
        }
    }

    $reference = '';
    if (($booking->id ?? 0) > 0) {
        $annee = $booking->created_at ? $booking->created_at->format('Y') : now()->format('Y');
        $reference = $annee . '-' . str_pad((string) $booking->id, 4, '0', STR_PAD_LEFT);
    }

    // Le moment ou ce document est produit : a la creation de la
    // reservation, comme apres une prolongation qui le refait.
    $etabliLe = now()->format('d/m/Y') . ' at ' . now()->format('H:i');

    // L'heure convenue avec le client ; a defaut, celle d'usage.
    $heureSortie = \App\Services\HeuresSejour::depart($booking);

    /**
     * Le corps d'une valeur, ajuste a sa longueur.
     *
     * La fiche doit tenir sur une page quoi qu'elle contienne : plutot
     * que de laisser une adresse a rallonge ajouter des lignes, on
     * reduit le corps jusqu'a ce qu'elle rentre. L'adresse dispose de
     * deux lignes, les autres champs d'une seule.
     */
    $corps = function ($valeur, bool $deuxLignes = false): string {
        $n = mb_strlen(trim((string) $valeur));
        $tient = $deuxLignes ? 72 : 36;

        if ($n <= $tient)             return '11pt';
        if ($n <= (int) ($tient * 1.2)) return '10pt';
        if ($n <= (int) ($tient * 1.4)) return '9pt';
        return '8pt';
    };

    /**
     * Le type d'invites, en anglais, avec son equivalent arabe.
     *
     * La base retient des codes anglais : on les garde, et l'arabe
     * suit entre parentheses, comme sur le bulletin de Godar.
     */
    $invitesEnArabe = [
        'Males'                 => 'رجال',
        'Females'               => 'نساء',
        'Family'                => 'عائلة',
        'Professional visitors' => 'زوار مهنيون',
    ];
    $codeInvite = trim((string) ($booking->type_guest ?? ''));
    $typeInvite = $codeInvite === ''
        ? ''
        : $codeInvite . (isset($invitesEnArabe[$codeInvite])
            ? ' (' . $invitesEnArabe[$codeInvite] . ')'
            : '');

    // Prolongation, raccourcissement ou modification : l'ancienne valeur reste lisible.
    $nuitsDelta = !empty($oldCheckout)
        ? (int) round(\Carbon\Carbon::parse($oldCheckout)->startOfDay()->diffInDays(\Carbon\Carbon::parse($booking->checkout)->startOfDay(), false))
        : 0;
    $deltaTexte = $nuitsDelta > 0 ? '(+' . $nuitsDelta . ' j)' : ($nuitsDelta < 0 ? '(' . $nuitsDelta . ' j)' : '');
    // L'ancienne date reste lisible, barree, devant la nouvelle.
    $departTexte = !empty($oldCheckout)
        ? new \Illuminate\Support\HtmlString('<span style="text-decoration:line-through;color:#999;">' . e($date($oldCheckout)) . '</span>&nbsp; '
            . e($date($booking->checkout)) . ($deltaTexte !== '' ? '&nbsp; ' . e($deltaTexte) : ''))
        : $date($booking->checkout);
    $titreType = !empty($type)
        ? trim((['extend' => 'Prolongation', 'shrink' => 'Raccourcissement', 'modification' => 'Modification du prix'][$type] ?? $type) . ' ' . $deltaTexte)
        : '';

    $lignes = [
        ['First Name',          trim(($client->first_name ?? '') . ($prenomAr !== '' ? '  /  ' . $prenomAr : '')), 'الإسم الشخصي'],
        ['Last Name',           trim(($client->last_name ?? '') . ($nomAr !== '' ? '  /  ' . $nomAr : '')),        'الاسم العائلي'],
        ['ID / Passport No.',   $client->identity_number ?? '',                'رقم بطاقة التعريف / جواز السفر'],
        ['Nationality',          (in_array(mb_strtolower(trim((string) ($client->nationalite ?? ''))), ['marocain', 'marocaine', 'مغربي', 'مغربية'], true) ? 'Marocain مغربي' : ($client->nationalite ?? '')), 'الجنسية'],
        ['Duration',             $duree,                                        'المدة'],
        ['Number of visitors',   (string) ($booking->nb_guest ?? ''),           'عدد الزوار'],
        ['Date of Entry',        $date($booking->checkin),                      'تاريخ الدخول'],
        ['Date of Departure',    $departTexte,                                  'تاريخ الخروج'],
        ['Departure Time',       $heureSortie,                                  'توقيت الخروج'],
        ['Marital Status',       $typeInvite, 'الحالة العائلية'],
        ['Phone Number',         $telephone,                                    'رقم الهاتف', false, true],
        ['Address',              $adresseBien,                                  'عنوان الشقة', true],
    ];

    // Le numero du client ne figure que sur l'exemplaire interne : le
    // document qu'il emporte n'a pas a le promener.
    if (!$isPrivate) {
        $lignes = array_values(array_filter($lignes, fn ($ligne) => empty($ligne[4])));
    }


    /**
     * L'agent qui a etabli la reservation.
     *
     * C'est lui qui signe pour l'agence : le client sait a qui il a
     * affaire, et qui appeler. L'apercu, lui, n'a pas encore de
     * reservation : il recoit l'agent en cours.
     */
    $agent = $booking->manager ?? ($manager ?? null);
    $nomAgent = trim(($agent->first_name ?? '') . ' ' . ($agent->last_name ?? ''));
    $telAgent = \App\Services\Telephone::local($agent->phone ?? '');

    $caseAgence = 'Booking Agent';
    $caseAgence .= '<br>' . e($nomAgent !== '' ? $nomAgent : "Agency Signature");
    if ($telAgent !== '') {
        $caseAgence .= '<br>' . e($telAgent);
    }

    /**
     * La taille d'une image de signature ou de cachet, ramenee dans un
     * cadre fixe sans la deformer.
     *
     * Les signatures tracees sur le telephone ont toutes les proportions :
     * une signature haute, affichee a largeur fixe, montait jusqu'a 34 mm
     * et poussait la fin du contrat sur une deuxieme page. Le cadre fixe
     * garde le contrat sur une seule page, quelle que soit la signature.
     */
    /**
     * L'exemplaire interne porte en plus les montants et le telephone :
     * il est plus haut, et la signature du client s'y ajoute. Ses lignes
     * sont un peu plus serrees pour qu'il tienne, lui aussi, sur une
     * seule page. L'exemplaire du client garde sa mise en page aeree.
     */
    $serre = !empty($isPrivate);
    $pasLigne = $serre ? '1.8mm' : '3.2mm';

    $cadrer = function (?string $image, float $largeurMax, float $hauteurMax): string {
        $l = $largeurMax;
        $h = $hauteurMax;
        if ($image && str_contains($image, 'base64,')) {
            $taille = @getimagesizefromstring(base64_decode(substr($image, strpos($image, 'base64,') + 7)));
            if ($taille && $taille[0] > 0 && $taille[1] > 0) {
                $echelle = min($largeurMax / $taille[0], $hauteurMax / $taille[1]);
                $l = $taille[0] * $echelle;
                $h = $taille[1] * $echelle;
            }
        }
        return sprintf('width: %.1fmm; height: %.1fmm;', $l, $h);
    };

    /**
     * Les correspondants du pied de page.
     *
     * Lus dans la configuration, sous la forme « Nom:numero » separee
     * par des virgules ; le numero du compte prend le relais si la
     * liste est vide.
     */
    $correspondants = [];
    foreach (preg_split('/\s*,\s*/', (string) config('agence.contacts'), -1, PREG_SPLIT_NO_EMPTY) as $entree) {
        $morceaux = explode(':', $entree, 2);
        if (count($morceaux) === 2 && trim($morceaux[1]) !== '') {
            $correspondants[] = [trim($morceaux[0]), trim($morceaux[1])];
        }
    }
    if (!$correspondants && $telAgence) {
        $correspondants[] = [$nomAgence, $telAgence];
    }
@endphp
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <style>
        @page { margin: 8mm 9mm 5mm 9mm; }

        body {
            font-family: sans-serif;
            font-size: 9pt;
            color: #000000;
        }

        /* ── En-tete ─────────────────────────────────────────────── */
        .marque { text-align: center; margin-bottom: 2mm; }

        .reference {
            text-align: right;
            font-size: 10pt;
            font-weight: bold;
            color: #000000;
            margin-top: 0.6mm;
        }
        .etabli {
            text-align: right;
            font-size: 8.5pt;
            color: #444444;
        }
        .porte-titre {
            text-align: center;
            margin-top: 0.6mm;
            margin-bottom: 3.4mm;
        }
        .porte-cond {
            text-align: center;
            margin-bottom: 2.4mm;
        }
        .etiquette-titre {
            display: inline-block;
            width: 84mm;
            margin: 0 auto;
            text-align: center;
            background: {{ $ardoise }};
            color: #ffffff;
            font-weight: bold;
            border-radius: 3.4mm;
            font-size: 12.5pt;
            letter-spacing: 0.35mm;
            padding: 2mm 8mm;
        }
        .etiquette-cond {
            display: inline-block;
            width: 96mm;
            margin: 0 auto;
            text-align: center;
            background: {{ $ardoise }};
            color: #ffffff;
            font-weight: bold;
            border-radius: 3.4mm;
            font-size: 12pt;
            padding: 1.8mm 7mm;
        }

        /* ── Cadre des renseignements ───────────────────────────── */
        .cadre {
            border: 0.7mm solid {{ $couleur }};
            border-radius: 4.5mm;
            padding: 2.8mm 6mm;
            margin-bottom: 3mm;
            @if ($filigrane)
            background-image: url("{{ $filigrane }}");
            background-position: 50% 50%;
            background-repeat: no-repeat;
            background-image-resize: 2;
            @endif
        }

        table.champs { width: 100%; border-collapse: collapse; }
        table.champs td {
            padding: {{ $pasLigne }} 0 0 0;
            vertical-align: bottom;
        }
        /* Plus specifique que la regle ci-dessus, sans quoi elle
           l'emporterait et les pointilles s'ecarteraient du texte. */
        table.champs td.valeur {
            padding: {{ $pasLigne }} 2.5mm 0.3mm 2.5mm;
        }

        .fr {
            width: 27%;
            /* FreeSerif reprend les dessins et les chasses de Times
               New Roman, la romaine du formulaire papier. */
            font-family: freeserif;
            font-weight: bold;
            color: #000000;
            font-size: 11.5pt;
            white-space: nowrap;
        }
        .valeur {
            width: 43%;
            font-family: freeserif;
            font-weight: bold;
            color: #000000;
            border-bottom: 0.25mm dotted #4f5354;
            text-align: center;
            font-size: 11pt;
        }
        .ar {
            /* La police du formulaire papier de l'agence. */
            font-family: traditionalarabic;
            color: #000000;
            width: 30%;
            text-align: right;
            font-weight: bold;
            font-size: 12pt;
            direction: rtl;
            white-space: nowrap;
        }

        /* ── Conditions ─────────────────────────────────────────── */
        /* Les conditions se resserrent un peu sur l'exemplaire interne. */
        .conditions {
            background: #f6f6f6;
            border-radius: 2.5mm;
            padding: 2.4mm 4mm;
            font-size: 8pt;
            color: #000000;
            line-height: 1.32;
            margin-bottom: 2.5mm;
        }
        .conditions p { margin: 0 0 1.4mm 0; }

        table.table-conditions { width: 100%; border-collapse: collapse; }
        table.table-conditions td {
            padding: 0.45mm 0 0.45mm 0;
            vertical-align: top;
        }

        /* L'anglais a gauche, l'arabe a droite : chacun dans son sens. */
        .cond-en {
            width: 49%;
            direction: ltr;
            text-align: left;
            font-family: freeserif;
            font-size: 7pt;
            padding-right: 3mm !important;
        }
        .cond-ar {
            width: 51%;
            direction: rtl;
            text-align: right;
            font-family: traditionalarabic;
            font-size: 8pt;
        }
        .coche {
            font-family: dejavusans;
            color: {{ $couleur }};
            font-weight: bold;
        }

        /* ── Detail du sejour, exemplaire interne ───────────────── */
        .sejour {
            border: 0.7mm solid {{ $couleur }};
            border-radius: 4.5mm;
            padding: 2.4mm 5mm;
            margin-bottom: 3mm;
            font-size: 9pt;
        }
        .sejour .titre {
            text-align: center;
            font-weight: bold;
            color: {{ $couleur }};
            margin-bottom: 1.2mm;
            font-size: 9pt;
        }
        table.montants { width: 100%; border-collapse: collapse; }
        table.montants td { padding: {{ $serre ? '0.6mm' : '1mm' }} 3mm {{ $serre ? '0.6mm' : '1mm' }} 0; }
        table.montants td {
            border-bottom: 0.2mm solid #d7e3e4;
        }
        table.montants tr:last-child td { border-bottom: 0; }
        table.montants .lib { width: 34%; color: #333; white-space: nowrap; }
        table.montants .val {
            width: 32%;
            text-align: center;
            font-weight: bold;
            white-space: nowrap;
        }
        table.montants .lib-ar {
            width: 34%;
            text-align: right;
            direction: rtl;
            font-family: traditionalarabic;
            font-weight: bold;
            font-size: 10.5pt;
        }
        /* Le total se detache, comme sur le bulletin Godar. */
        table.montants tr.ligne-total td {
            background-color: #eaf4f5;
            font-weight: bold;
            font-size: 9.5pt;
        }
        table.montants tr.reste td {
            border-top: 0.25mm solid #cfcfcf;
            padding-top: 1.4mm;
            font-weight: bold;
            font-size: 9.5pt;
        }

        /* ── Signatures ─────────────────────────────────────────── */
        table.signatures { width: 100%; border-collapse: collapse; margin-top: {{ $serre ? '0.5mm' : '3mm' }}; }
        td.sig { width: 33.33%; text-align: center; vertical-align: top; padding: 0; }

        table.mini { width: 100%; border-collapse: collapse; }
        table.boite-signature {
            border-collapse: collapse;
            margin: 0 auto;
        }
        /* Ni cadre ni fond : les noms se posent a meme le document. */
        td.case-signature {
            font-family: traditionalarabic;
            padding: 1.6mm 4mm;
            line-height: 1.45;
            font-size: 8.5pt;
            font-weight: bold;
            text-align: center;
        }
        .cachet { margin-top: 2mm; }
        .paraphe { margin-top: 1.5mm; }
        .trait-signature {
            border-top: 0.3mm solid {{ $ardoise }};
            width: 70%;
            margin: 0 auto;
        }

        /* ── Pied de page ───────────────────────────────────────── */
        .pied {
            margin-top: {{ $serre ? '1mm' : '5mm' }};
            text-align: center;
            color: {{ $couleur }};
            font-family: serif;
            font-size: 8.8pt;
            line-height: 1.7;
        }
        .pied p { margin: 0; }
        .signe { font-family: sans-serif; font-size: 8pt; }

        .filigrane-apercu {
            position: fixed;
            top: 45%;
            left: 12%;
            font-size: 40pt;
            color: rgba(0, 0, 0, 0.07);
            font-weight: bold;
        }
    </style>
</head>
<body>

@if ($apercu)
    <div class="filigrane-apercu">PREVIEW</div>
@endif

{{-- La largeur est posee sur la balise : mPDF n'applique pas de maniere
     fiable un selecteur descendant comme « .marque img ». --}}
@if ($marque)
    <div class="marque"><img src="{{ $marque }}" style="width: 150mm;" alt=""></div>
@elseif ($logo)
    <div class="marque"><img src="{{ $logo }}" style="width: 25mm;" alt=""></div>
@endif

@if ($reference !== '')
    <div class="reference">Contract No. {{ $reference }}</div>
@endif
<div class="etabli">Issued on {{ $etabliLe }}@if ($titreType !== '') &nbsp;&middot;&nbsp; <b style="color:{{ $couleur }};">{{ $titreType }}</b>@endif</div>

<div class="porte-titre">
    <div class="etiquette-titre">BULLETIN D'HÉBERGEMENT</div>
</div>

<div class="cadre">
    <table class="champs">
        @foreach ($lignes as $ligne)
            @php
                [$fr, $valeur, $ar] = $ligne;
                $deuxLignes = $ligne[3] ?? false;
            @endphp
            <tr>
                <td class="fr">{{ $fr }} :</td>
                <td class="valeur" style="font-size: {{ $corps($valeur instanceof \Illuminate\Support\HtmlString ? html_entity_decode(strip_tags((string) $valeur)) : $valeur, $deuxLignes) }};">{{ $valeur }}</td>
                <td class="ar">{{ $ar }} :</td>
            </tr>
        @endforeach
    </table>
</div>

@if ($isPrivate)
    @php
        $prixNuit = (float) ($booking->night_price ?? 0);
        $total    = (float) ($booking->amount ?? 0);
        $avance   = (float) ($booking->avance ?? 0);
        $reste    = max(0, $total - $avance);
        $sou = fn($m) => number_format($m, 2, ',', ' ') . ' MAD';
    @endphp
    <div class="sejour">
        <div class="titre">STAY DETAILS &nbsp;&mdash;&nbsp; تفاصيل الإقامة</div>
        <table class="montants">
            <tr>
                <td class="lib">Price &times; number of nights</td>
                <td class="val">@if (!empty($oldPrixNuit) && abs((float) $oldPrixNuit - $prixNuit) > 0.009)<span style="text-decoration:line-through;color:#999;">{{ $sou((float) $oldPrixNuit) }}</span> @endif{{ $sou($prixNuit) }} × {{ max(1, $nuits) }}</td>
                <td class="lib-ar">المبلغ × عدد الليالي</td>
            </tr>
            <tr class="ligne-total">
                <td class="lib">Total stay</td>
                <td class="val">@if (!empty($oldTotal) && abs((float) $oldTotal - $total) > 0.009)<span style="text-decoration:line-through;color:#999;">{{ $sou((float) $oldTotal) }}</span> @endif{{ $sou($total) }}</td>
                <td class="lib-ar">المجموع</td>
            </tr>
        </table>
    </div>
@endif

<div class="porte-cond">
    <div class="etiquette-cond">Terms and Guidelines &nbsp;&nbsp; شروط و توجيهات</div>
</div>

<div class="conditions">
    {{-- Chaque condition dans les deux langues : l'anglais a gauche,
         l'arabe a droite. --}}
    <table class="table-conditions">
    <tr>
        <td class="cond-en"><span class="coche">&#10003;</span> The guest or resident undertakes to use the apartment in an ethical and responsible manner, and to refrain from anything that may damage the property or disturb the neighbours.</td>
        <td class="cond-ar">يلتزم النزيل أو المقيم باستخدام الشقة بطريقة أخلاقية و مسؤولة، وعدم القيام بأي أنشطة تؤدي إلى التشويه أو إتلاف للممتلكات أو إزعاج الجيران.</td>
    </tr>
    <tr>
        <td class="cond-en"><span class="coche">&#10003;</span> Using the apartment for any illegal or unethical purpose is prohibited : drugs, parties, or hosting unauthorised persons.</td>
        <td class="cond-ar">يمنع استخدام الشقة لأي أغراض غير قانونية أو غير أخلاقية، مثل تعاطي المخدرات أو تنظيم الحفلات أو استقبال أشخاص غير مصرح بهم.</td>
    </tr>
    <tr>
        <td class="cond-en"><span class="coche">&#10003;</span> Should the guest or resident breach any clause on the ethical use of the apartment, they bear full financial and moral responsibility and cover every cost arising from it.</td>
        <td class="cond-ar">في حالة انتهاك النزيل أو المقيم لأي من بنود العقد المتعلقة بالاستخدام الأخلاقي للشقة، يتحمل النزيل أو المقيم المسؤولية المادية والمعنوية، ويتحمل جميع التكاليف الناتجة عن هذا الانتهاك.</td>
    </tr>
    <tr>
        <td class="cond-en"><span class="coche">&#10003;</span> Mixed-gender occupancy without a marriage certificate is strictly forbidden.</td>
        <td class="cond-ar">يمنع منعا كليا دخول الجنسين معا بدون عقد الزواج.</td>
    </tr>
    <tr>
        <td class="cond-en"><span class="coche">&#10003;</span> I certify that all the information given is accurate and undertake to comply with every term above.</td>
        <td class="cond-ar">أقر بصحة كافة المعلومات وأتعهد بالالتزام بجميع الشروط المذكورة.</td>
    </tr>
    </table>
</div>

<table class="signatures">
    <tr>
        <td class="sig">
            <table class="boite-signature"><tr>
                <td class="case-signature">Client Signature<br>إمضاء المــــقيم</td>
            </tr></table>
            <div style="font-size:7pt;font-style:italic;text-align:center;margin-top:0.8mm;">Lu, approuvé et accepté</div>
            @if ($signature)
                <div><img class="paraphe" src="{{ $signature }}" style="{{ $cadrer($signature, 45, 12) }}" alt=""></div>
            @endif
        </td>
        <td class="sig">
            {{-- mPDF ne rend pas la balise <barcode> a l'interieur d'une
                 cellule de tableau : le code est donc produit en image. --}}
            @if ($qrImage)
                <img src="{{ $qrImage }}" style="width: 22mm;" alt="">
            @endif
        </td>
        <td class="sig">
            <table class="boite-signature"><tr>
                <td class="case-signature">{!! $caseAgence !!}</td>
            </tr></table>
            @if ($cachet)
                <div><img class="cachet" src="{{ $cachet }}" style="{{ $cadrer($cachet, 42, 11) }}" alt=""></div>
            @else
                <div class="trait-signature" style="margin-top:9mm"></div>
            @endif
        </td>
    </tr>
</table>

<div class="pied">
    @if ($correspondants)
        <p>@foreach ($correspondants as $i => [$qui, $numero])@if ($i) &nbsp;&ndash;&nbsp; @endif<span class="signe">&#9742;</span> <b>{{ $numero }}</b>@endforeach</p>
    @endif
    @if ($adresseAgence)
        <p><span class="signe">&#9873;</span> ADDRESS: {{ $adresseAgence }}</p>
    @endif
    @if ($emailAgence)
        <p><span class="signe">&#9993;</span> {{ $emailAgence }}</p>
    @endif
</div>

</body>
</html>
