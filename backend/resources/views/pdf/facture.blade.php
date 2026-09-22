@php
    /**
     * Facture ALWED LH.
     *
     * Le papier a en-tete de l'agence sert de fond de page : bandeaux,
     * logo, pastille « Facture N » , filigrane et pied y sont deja. Ne
     * restent a placer que les donnees de la reservation, calees sur les
     * reperes du papier.
     */

    $couleur = '#43B2BC';
    $ardoise = '#697274';

    $client = $booking->client;
    $bien   = $booking->realestate;

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

    $nuits    = max(1, (int) ($booking->nb_days ?? 0));
    $prixNuit = (float) ($booking->night_price ?? 0);
    $total    = (float) ($booking->amount ?? 0);

    $sou = fn ($m) => number_format($m, 2, ',', ' ') . ' MAD';

    $designation = trim((string) ($bien->title ?? ''));
    if ($designation === '') {
        $designation = 'Location saisonnière';
    }

    $adresseBien = trim(($bien->address ?? '') . ' ' . ($bien->city->name ?? ''));

    $nomClient = trim(($client->first_name ?? '') . ' ' . ($client->last_name ?? ''));
    $telephone = \App\Services\Telephone::local($client->tel ?? '');

    // Un numero lisible et stable : l'annee, puis l'identifiant de la
    // reservation. Deux factures ne peuvent pas le partager.
    $numero = ($booking->created_at ? $booking->created_at->format('Y') : now()->format('Y'))
        . '-' . str_pad((string) $booking->id, 4, '0', STR_PAD_LEFT);

    $etablieLe = now()->format('d/m/Y');
@endphp
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <style>
        @page { margin: 0; }

        body {
            margin: 0;
            font-family: freeserif;
            font-size: 10pt;
            color: #000000;
        }

        /* Le corps commence sous la pastille du papier et s'arrete
           au-dessus de la bande du pied. */
        .corps { padding: 92mm 20mm 0 20mm; }

        /* Le numero se pose dans la pastille, qui est turquoise. */
        .numero {
            margin-left: 43.5mm;
            color: #ffffff;
            font-family: dejavusans;
            font-weight: bold;
            font-size: 11.5pt;
        }

        .etablie {
            text-align: right;
            font-size: 9.5pt;
            color: #333333;
            margin-top: 6mm;
        }

        .destinataire {
            margin-top: 2mm;
            margin-bottom: 6mm;
        }
        .intitule {
            font-family: dejavusans;
            font-size: 8pt;
            font-weight: bold;
            letter-spacing: 0.3mm;
            color: {{ $couleur }};
            margin-bottom: 1.4mm;
        }
        .destinataire .nom { font-size: 12pt; font-weight: bold; }

        table.lignes {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 6mm;
        }
        table.lignes th {
            background: {{ $ardoise }};
            color: #ffffff;
            font-family: dejavusans;
            font-size: 8.5pt;
            font-weight: bold;
            text-align: left;
            padding: 2.2mm 3mm;
        }
        table.lignes td {
            padding: 3mm;
            font-size: 10.5pt;
            border-bottom: 0.2mm solid #cfd4d5;
            vertical-align: top;
        }
        td.nombre { text-align: right; white-space: nowrap; }
        th.nombre { text-align: right; }
        .sous-ligne { font-size: 8.5pt; color: #4a5052; }

        table.totaux {
            width: 82mm;
            border-collapse: collapse;
            margin-left: 88mm;
        }
        table.totaux td {
            padding: 1.9mm 3mm;
            font-size: 10.5pt;
        }
        td.libelle { color: #3c4244; }
        td.valeur { text-align: right; font-weight: bold; white-space: nowrap; }
        tr.du td {
            background: {{ $couleur }};
            color: #ffffff;
            font-size: 11.5pt;
            font-weight: bold;
        }

        .mention {
            margin-top: 7mm;
            font-size: 9pt;
            color: #3c4244;
        }
    </style>
</head>
<body>

<div class="corps">

    <div class="numero">{{ $numero }}</div>

    <div class="etablie">Établie le {{ $etablieLe }}</div>

    <div class="destinataire">
        <div class="intitule">FACTURÉ À</div>
        <div class="nom">{{ $nomClient !== '' ? $nomClient : 'Client' }}</div>
        @if ($client->identity_number)
            <div>C.I.N / Passeport : {{ $client->identity_number }}</div>
        @endif
        @if ($telephone !== '')
            <div>Téléphone : {{ $telephone }}</div>
        @endif
    </div>

    <table class="lignes">
        <tr>
            <th>Désignation</th>
            <th class="nombre">Nuitées</th>
            <th class="nombre">Prix / nuit</th>
            <th class="nombre">Montant</th>
        </tr>
        <tr>
            <td>
                {{ $designation }}
                @if ($adresseBien !== '')
                    <div class="sous-ligne">{{ $adresseBien }}</div>
                @endif
                <div class="sous-ligne">
                    Du {{ $date($booking->checkin) }} au {{ $date($booking->checkout) }}
                </div>
            </td>
            <td class="nombre">{{ $nuits }}</td>
            <td class="nombre">{{ $sou($prixNuit) }}</td>
            <td class="nombre">{{ $sou($total) }}</td>
        </tr>
    </table>

    <table class="totaux">
        <tr class="du">
            <td class="libelle">Total</td>
            <td class="valeur">{{ $sou($total) }}</td>
        </tr>
    </table>

    <div class="mention">
        Arrêtée la présente facture à la somme de {{ $sou($total) }}.
    </div>

</div>

</body>
</html>
