<?php

namespace App\Services;

use App\Models\Booking;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Mpdf\Mpdf;

/**
 * La facture d'un sejour, au modele de l'agence : en-tete, client (avec
 * ICE pour une societe), montant H.T, T.V.A et T.T.C, signature et
 * cachet, pied de page avec les coordonnees de l'agence.
 *
 * Le numero est attribue une fois, a la premiere edition, et ne change
 * plus ; les montants suivent la reservation.
 */
class FactureAgence
{
    public static function reglage(string $cle, string $defaut = ""): string
    {
        $v = DB::table("reglages_agence")->where("cle", $cle)->value("valeur");
        return trim((string) ($v ?? $defaut));
    }

    public static function estAlwed(): bool
    {
        return str_contains(strtolower((string) config("app.name")), "alwed");
    }

    /** La facture d'une reservation, creee au premier besoin ; le client peut etre precise. */
    public static function pour(Booking $booking, array $client = [], ?int $par = null): object
    {
        $ligne = DB::table("factures")->where("booking_id", $booking->id)->first();
        $nom = trim(($booking->client->first_name ?? "") . " " . ($booking->client->last_name ?? ""));
        $valeurs = array_filter([
            "client_nom"     => ($client["nom"] ?? null) === "" ? null : ($client["nom"] ?? null),
            "taux_tva"       => isset($client["tva"]) && $client["tva"] !== "" ? (float) $client["tva"] : null,
        ], fn($v) => $v !== null);
        // L'ICE et l'adresse peuvent etre effacees : une chaine vide vaut « aucune ».
        foreach (["ice" => "client_ice", "adresse" => "client_adresse"] as $cle => $col) {
            if (array_key_exists($cle, $client) && $client[$cle] !== null) {
                $valeurs[$col] = $client[$cle] === "" ? null : $client[$cle];
            }
        }

        return DB::transaction(function () use ($ligne, $booking, $valeurs, $nom, $par) {
            if (!$ligne) {
                $numero = (int) DB::table("factures")->lockForUpdate()->max("numero") + 1;
                DB::table("factures")->insert([
                    "numero" => $numero, "booking_id" => $booking->id, "date_facture" => today()->toDateString(),
                    "client_nom" => $valeurs["client_nom"] ?? $nom, "client_ice" => $valeurs["client_ice"] ?? null,
                    "client_adresse" => $valeurs["client_adresse"] ?? null,
                    "montant_ttc" => round((float) $booking->amount, 2), "taux_tva" => $valeurs["taux_tva"] ?? 20,
                    "created_by" => $par, "created_at" => now(), "updated_at" => now(),
                ]);
            } else {
                DB::table("factures")->where("id", $ligne->id)->update($valeurs + ["updated_at" => now()]);
            }
            return DB::table("factures")->where("booking_id", $booking->id)->first();
        });
    }

    public static function numero(object $f): string
    {
        return empty($f->numero) ? "APERÇU" : str_pad((string) $f->numero, 4, "0", STR_PAD_LEFT);
    }

    /**
     * Les montants : le total de la reservation est le H.T, la T.V.A
     * s'y ajoute. Une facture appliquee garde ses montants figes.
     */
    public static function montants(Booking $booking, ?object $f): array
    {
        $taux = $f && $f->taux_tva !== null ? (float) $f->taux_tva : 20.0;
        if ($f && !empty($f->appliquee_le) && $f->montant_ht !== null) {
            $ht = (float) $f->montant_ht;
            $tva = (float) $f->montant_tva;
        } else {
            $ht = round((float) $booking->amount, 2);
            $tva = round($ht * $taux / 100, 2);
        }
        return ["ht" => $ht, "tva" => $tva, "ttc" => round($ht + $tva, 2), "taux" => $taux];
    }

    /**
     * Facture appliquee des la creation de la reservation : le total est le
     * T.T.C, la T.V.A y est comprise. Rien n'entre en plus dans la caisse :
     * le total de la reservation y est deja encaisse.
     */
    public static function appliquerIncluse(Booking $booking, float $taux = 20.0, ?int $par = null): object
    {
        $taux = max(0.0, min(30.0, $taux));
        $f = static::pour($booking, ["tva" => $taux], $par);
        if (!empty($f->appliquee_le)) {
            return $f;
        }
        $ttc = round((float) $booking->amount, 2);
        $ht = $taux > 0 ? round($ttc / (1 + $taux / 100), 2) : $ttc;
        DB::table("factures")->where("id", $f->id)->update([
            "taux_tva" => $taux, "montant_ht" => $ht, "montant_tva" => round($ttc - $ht, 2), "montant_ttc" => $ttc,
            "tva_incluse" => true, "date_facture" => today()->toDateString(), "appliquee_le" => now(), "appliquee_par" => $par,
            "statut_paiement" => "paye", "paye_le" => now(), "montant_encaisse" => 0, "updated_at" => now(),
        ]);
        return DB::table("factures")->find($f->id);
    }

    /** Ce que montre la facture tant qu'elle n'est pas appliquee : sans numero. */
    public static function apercu(Booking $booking): object
    {
        $f = DB::table("factures")->where("booking_id", $booking->id)->first();
        if ($f && !empty($f->appliquee_le)) {
            return $f;
        }
        return (object) [
            "numero" => null, "date_facture" => today()->toDateString(),
            "client_nom" => $f->client_nom ?? trim(($booking->client->first_name ?? "") . " " . ($booking->client->last_name ?? "")),
            "client_ice" => $f->client_ice ?? null, "client_adresse" => $f->client_adresse ?? null,
            "taux_tva" => $f->taux_tva ?? 20, "montant_ht" => null, "montant_tva" => null, "appliquee_le" => null,
        ];
    }

    private static function image(?string $chemin): string
    {
        if (!$chemin || !is_readable($chemin)) return "";
        return "data:" . (mime_content_type($chemin) ?: "image/png") . ";base64," . base64_encode(file_get_contents($chemin));
    }

    private static function m(float $v): string
    {
        return number_format($v, 2, ",", " ");
    }

    public static function pdf(Booking $booking, object $f): string
    {
        $booking->loadMissing(["client", "realestate.city"]);
        $alwed = static::estAlwed();
        $couleur = $alwed ? "#3AAFB9" : "#1F5F8B";
        $nomAgence = static::reglage("entete_nom", $alwed ? "STE ALWED LH" : (string) config("app.name"));
        $sousTitre = static::reglage("entete_sous_titre", "Agence immobilière");
        $ice = static::reglage("entete_ice");
        $adresse = static::reglage("entete_adresse");
        $email = static::reglage("entete_email");
        $tel = static::reglage("entete_tel");
        $reseaux = static::reglage("entete_reseaux");
        $ville = static::reglage("entete_ville", "AGADIR");

        $agence = User::where("agence", "1")->first();
        $logoProfil = null;
        try { $logoProfil = $agence?->getFirstMedia("profile_photo")?->getPath(); } catch (\Throwable $e) {}
        $logo = static::image($alwed ? resource_path("views/pdf/assets/alwed-icone-gris.png") : $logoProfil);
        $filigrane = $alwed ? resource_path("views/pdf/assets/alwed-filigrane.png") : $logoProfil;
        $cachet = static::image(storage_path("app/public/cachet-agence.png"));

        ["ht" => $ht, "tva" => $tva, "ttc" => $ttc, "taux" => $taux] = static::montants($booking, $f);

        $du = Carbon::parse($booking->checkin)->format("d/m/Y");
        $au = Carbon::parse($booking->checkout)->format("d/m/Y");
        $bien = trim(($booking->realestate->title ?? ""));
        $numero = static::numero($f);
        $date = Carbon::parse($f->date_facture)->format("d/m/Y");

        $mpdf = new Mpdf(array_merge(is_array(config("pdf.polices")) ? config("pdf.polices") : [], [
            "mode" => "utf-8", "format" => "A4", "orientation" => "P",
            "margin_left" => 0, "margin_right" => 0, "margin_top" => 0, "margin_bottom" => 34, "margin_footer" => 0,
            "autoScriptToLang" => true, "autoLangToFont" => true,
        ]));
        if ($filigrane && is_readable($filigrane)) {
            $mpdf->SetWatermarkImage($filigrane, $alwed ? 0.55 : 0.07, [120, 150], [45, 75]);
            $mpdf->showWatermarkImage = true;
            $mpdf->watermarkImgBehind = true;
        }

        $qr = "Facture " . $numero . " | " . $nomAgence . ($ice ? " | ICE " . $ice : "") . " | TTC " . static::m($ttc) . " MAD | " . $date;
        $mpdf->SetHTMLFooter('
<div style="padding:0 14mm;">
  <table width="100%" style="border-top:1.4px solid #9aa4aa; font-family:sans-serif; font-size:9.5pt; color:#555;"><tr>
    <td style="padding-top:4px;">' . ($ice ? 'ICE : ' . e($ice) . '<br/>' : '') . ($adresse ? 'ADRESSE : ' . e($adresse) : '') . '</td>
    <td align="right" width="70"><barcode code="' . e($qr) . '" type="QR" size="0.62" error="M" disableborder="1" /></td>
  </tr></table>
</div>
<table width="100%" style="background:' . $couleur . '; color:#fff; font-family:sans-serif; font-size:9.5pt;"><tr>
  <td style="padding:7px 14mm;">' . ($reseaux ? '&#9673; ' . e($reseaux) : '') . '</td>
  <td align="center">' . ($email ? '&#9993; ' . e($email) : '') . '</td>
  <td align="right" style="padding-right:14mm;">' . ($tel ? '&#9742; ' . e($tel) : '') . '</td>
</tr></table>');

        $html = '<style>
  body { font-family: sans-serif; color: #1d1d1d; }
  .page { padding: 10mm 14mm 0 14mm; }
  table.entete { width: 100%; border-collapse: collapse; }
  td.logo { width: 42mm; text-align: center; vertical-align: middle; padding: 3mm 0; }
  td.bande { background: ' . $couleur . '; color: #fff; padding: 5mm 8mm; vertical-align: middle; }
  .nom { font-size: 30pt; font-weight: bold; font-style: italic; letter-spacing: 2px; }
  .sous { font-size: 13pt; font-weight: bold; font-family: serif; }
  .titre { text-align: center; font-size: 22pt; font-weight: bold; text-decoration: underline; font-style: italic; margin: 12mm 0 6mm 0; }
  .lieu { text-align: right; font-size: 13pt; font-weight: bold; font-style: italic; margin-bottom: 8mm; }
  .client { font-size: 14pt; font-weight: bold; font-style: italic; line-height: 1.6; margin-bottom: 8mm; }
  table.lignes { width: 100%; border-collapse: collapse; font-size: 13pt; }
  table.lignes th { border: 0.8px solid #333; padding: 4mm; font-style: italic; font-size: 14pt; }
  table.lignes td { border: 0.8px solid #333; padding: 5mm 4mm; vertical-align: top; font-style: italic; }
  table.totaux { font-size: 11pt; font-style: italic; margin-top: 10mm; }
  table.totaux td { padding: 1px 6px; }
  table.tva { border-collapse: collapse; font-size: 10.5pt; font-style: italic; margin-top: 3mm; }
  table.tva td { border: 0.6px solid #333; padding: 2px 10px; text-align: center; }
  .signature { font-size: 11pt; font-style: italic; margin-top: 6mm; }
</style>
<div class="page">
<table class="entete"><tr>
  <td class="logo">' . ($logo ? '<img src="' . $logo . '" style="height:24mm;" />' : '') . '</td>
  <td class="bande"><div class="nom">' . e($nomAgence) . '</div><div class="sous">' . e($sousTitre) . '</div></td>
</tr></table>
<div class="titre">' . (empty($f->numero) ? 'Facture (aperçu, non appliquée)' : 'Facture N° : ' . $numero) . '</div>
<div class="lieu">' . e(mb_strtoupper($ville)) . ' Le : ' . $date . '</div>
<div class="client">Client : ' . e($f->client_nom) . ($f->client_ice ? '<br/>ICE : ' . e($f->client_ice) : '')
            . ($f->client_adresse ? '<br/><span style="font-size:11pt;font-weight:normal;">' . e($f->client_adresse) . '</span>' : '') . '</div>
<table class="lignes">
  <tr><th width="72%">Désignation</th><th>Montant H.T</th></tr>
  <tr><td height="85mm">Location d\'appartement meublé :<br/>(du ' . $du . ' au ' . $au . ')'
            . ($bien !== "" ? '<br/><span style="font-size:10.5pt;color:#555;">' . e($bien) . '</span>' : '') . '</td>
      <td align="center">' . static::m($ht) . '</td></tr>
</table>
<table width="100%"><tr><td width="55%" valign="bottom"><div class="signature">Signature</div>' . ($cachet ? '<img src="' . $cachet . '" style="height:24mm;" />' : '') . '</td>
<td align="right" valign="top">
  <table class="totaux" align="right">
    <tr><td>Montant H.T :</td><td align="right">' . static::m($ht) . ' dh</td></tr>
    <tr><td>Montant T.V.A :</td><td align="right">' . static::m($tva) . ' dh</td></tr>
    <tr><td><b>Montant T.T.C :</b></td><td align="right"><b>' . static::m($ttc) . ' dh</b></td></tr>
  </table>
  <table class="tva" align="right"><tr><td>Taux</td><td>H.T</td><td>T.V.A</td></tr>
    <tr><td>' . rtrim(rtrim(number_format($taux, 2, ".", ""), "0"), ".") . '%</td><td>' . static::m($ht) . '</td><td>' . static::m($tva) . '</td></tr></table>
</td></tr></table>
</div>';

        set_error_handler(fn() => true, E_WARNING | E_NOTICE | E_DEPRECATED | E_USER_WARNING | E_USER_NOTICE);
        try {
            $mpdf->WriteHTML($html);
            return $mpdf->Output("", "S");
        } finally {
            restore_error_handler();
        }
    }
}
