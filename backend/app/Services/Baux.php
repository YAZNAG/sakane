<?php

namespace App\Services;

use App\Models\Bail;
use App\Models\FinancialTransaction;
use App\Models\Loyer;
use App\Models\LoyerPaiement;
use App\Models\Manager;
use App\Models\MouvementCaisse;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Mpdf\Mpdf;
use Throwable;
use WasenderApi\WasenderClient;

/**
 * Les regles de la location longue duree.
 *
 * Chaque mois du bail est une echeance payable le jour ou commence la
 * periode (le 15 pour un bail commence le 15). L'argent recu entre dans
 * la caisse de l'agent et compte comme revenu du bien ; un paiement
 * annule est contre-passe, jamais efface.
 */
class Baux
{
    /** Envois WhatsApp coupes pendant les essais. */
    public static bool $envoisActifs = true;

    /** Documents non ranges sur le disque pendant les essais. */
    public static bool $documentsActifs = true;

    /** Le debut de la periode n (0 = premier mois), sans deborder en fin de mois. */
    public static function debutPeriode(Carbon $debut, int $n): Carbon
    {
        return $debut->copy()->addMonthsNoOverflow($n);
    }

    /** Cree les echeances manquantes entre le debut et la fin du bail. */
    public static function genererEcheancier(Bail $bail): int
    {
        $debut = Carbon::parse($bail->date_debut)->startOfDay();
        $fin = Carbon::parse($bail->date_fin)->startOfDay();
        $crees = 0;

        for ($n = 0; $n < 600; $n++) {
            $periode = static::debutPeriode($debut, $n);
            if ($periode->gt($fin)) {
                break;
            }
            $finPeriode = static::debutPeriode($debut, $n + 1)->subDay()->min($fin);

            $existe = Loyer::where("bail_id", $bail->id)->whereDate("periode_debut", $periode->toDateString())->exists();
            if ($existe) {
                continue;
            }

            // Un dernier mois incomplet est facture au prorata des jours.
            $montant = $bail->montantMensuel();
            $moisPlein = static::debutPeriode($debut, $n + 1)->subDay();
            if ($finPeriode->lt($moisPlein)) {
                $jours = (int) round($periode->diffInDays($finPeriode)) + 1;
                $joursMois = (int) round($periode->diffInDays($moisPlein)) + 1;
                $montant = round($montant * $jours / max($joursMois, 1), 2);
            }

            Loyer::create([
                "bail_id"       => $bail->id,
                "realestate_id" => $bail->realestate_id,
                "periode_debut" => $periode->toDateString(),
                "periode_fin"   => $finPeriode->toDateString(),
                "echeance"      => $periode->toDateString(),
                "montant"       => $montant,
                "paye"          => 0,
            ]);
            $crees++;
        }

        return $crees;
    }

    /** Un bail actif occupe-t-il deja ce bien sur ces dates ? */
    public static function bailEnConflit(int $bienId, string $du, string $au, ?int $sauf = null): ?Bail
    {
        return Bail::with("locataire")
            ->where("realestate_id", $bienId)
            ->where("statut", "actif")
            ->when($sauf, fn($q) => $q->where("id", "<>", $sauf))
            ->whereDate("date_debut", "<=", $au)
            ->whereDate("date_fin", ">=", $du)
            ->first();
    }

    public static function nom($personne): string
    {
        if (!$personne) {
            return "";
        }
        return trim(($personne->first_name ?? $personne->name ?? "") . " " . ($personne->last_name ?? ""));
    }

    public static function montant($v): string
    {
        return number_format((float) $v, 2, ",", " ");
    }

    public static function date($d): string
    {
        return $d ? Carbon::parse($d)->format("d/m/Y") : "";
    }

    /** Encaisse un paiement : caisse de l'agent, revenu du bien, quittance. */
    public static function encaisser(Loyer $loyer, float $montant, string $payeLe, string $mode, ?Manager $manager, array $extra = []): LoyerPaiement
    {
        $bail = $loyer->bail;
        $titre = $bail->bien->title ?? "bien";

        return DB::transaction(function () use ($loyer, $bail, $montant, $payeLe, $mode, $manager, $extra, $titre) {
            $paiement = LoyerPaiement::create([
                "loyer_id"   => $loyer->id,
                "bail_id"    => $bail->id,
                "montant"    => round($montant, 2),
                "paye_le"    => $payeLe,
                "mode"       => $mode,
                "reference"  => $extra["reference"] ?? null,
                "remarque"   => $extra["remarque"] ?? null,
                "manager_id" => $manager?->id,
            ]);

            $mouvement = Caisses::encaisser(Caisses::pour($manager), round($montant, 2), MouvementCaisse::LOYER, [
                "bail_id"     => $bail->id,
                "manager_id"  => $manager?->id,
                "libelle"     => "Loyer " . $loyer->libelle() . " - " . $titre,
                "commentaire" => LoyerPaiement::MODES[$mode] ?? $mode,
            ]);
            if ($mouvement) {
                $paiement->mouvement_caisse_id = $mouvement->id;
                $paiement->save();
            }

            FinancialTransaction::record("income", round($montant, 2),
                "Loyer " . $loyer->libelle() . " - " . $titre, $bail->realestate_id, null, null, $payeLe);

            $loyer->recalculer();
            return $paiement;
        });
    }

    /** Annule un paiement : contre-passation en caisse et annulation du revenu. */
    public static function annulerPaiement(LoyerPaiement $paiement, ?Manager $manager, ?string $motif): void
    {
        DB::transaction(function () use ($paiement, $manager, $motif) {
            $loyer = $paiement->loyer;
            $titre = $paiement->bail->bien->title ?? "bien";

            if ($paiement->mouvement_caisse_id) {
                $mouvement = MouvementCaisse::find($paiement->mouvement_caisse_id);
                if ($mouvement) {
                    Caisses::contrepasser($mouvement, $manager?->id, $motif ?: "Annulation d'un paiement de loyer");
                }
            }

            FinancialTransaction::record("cancellation", (float) $paiement->montant,
                "Annulation paiement loyer " . $loyer->libelle() . " - " . $titre, $paiement->bail->realestate_id);

            $paiement->update([
                "annule_le"        => now(),
                "annule_par"       => $manager?->id,
                "motif_annulation" => $motif,
            ]);
            $loyer->recalculer();
        });
    }

    // ------------------------------------------------------------------
    // Documents
    // ------------------------------------------------------------------

    private static function mpdf(string $orientation = "P"): Mpdf
    {
        ini_set("pcre.backtrack_limit", "50000000");
        $options = [
            "mode" => "utf-8", "format" => "A4", "orientation" => $orientation,
            "margin_left" => 16, "margin_right" => 16, "margin_top" => 14,
            "margin_bottom" => 18, "margin_footer" => 7,
            "autoScriptToLang" => true, "autoLangToFont" => true,
        ];
        $polices = config("pdf.polices");
        if (is_array($polices)) {
            $options = array_merge($polices, $options);
        }
        return new Mpdf($options);
    }

    private static function rendre(Mpdf $mpdf, string $html): string
    {
        set_error_handler(fn() => true, E_WARNING | E_NOTICE | E_DEPRECATED | E_USER_WARNING | E_USER_NOTICE);
        try {
            $mpdf->WriteHTML($html);
            return $mpdf->Output("", "S");
        } finally {
            restore_error_handler();
        }
    }

    private static function style(string $couleur): string
    {
        return '<style>
  body { font-family: sans-serif; color: #1b2a31; font-size: 10pt; line-height: 1.45; }
  table.bandeau { width: 100%; border-collapse: collapse; }
  .agence { font-size: 10pt; font-weight: bold; color: ' . $couleur . '; letter-spacing: 0.5px; }
  .coord { font-size: 8pt; color: #5b6b73; }
  .titre { font-size: 17pt; font-weight: bold; text-align: center; margin: 14px 0 2px 0; }
  .titre-ar { font-size: 14pt; text-align: center; color: #4a5b64; margin-bottom: 4px; }
  .ref { text-align: center; font-size: 8.5pt; color: #6b7b84; margin-bottom: 10px; }
  .filet { height: 3px; background: ' . $couleur . '; margin: 6px 0 8px 0; }
  h2 { font-size: 11pt; color: ' . $couleur . '; margin: 12px 0 4px 0; border-bottom: 0.5px solid #d5dde2; padding-bottom: 2px; }
  table.fiche { width: 100%; border-collapse: collapse; }
  table.fiche td { padding: 3px 4px; vertical-align: top; }
  table.fiche td.l { width: 34%; color: #56666e; }
  table.fiche td.v { font-weight: bold; }
  p { margin: 3px 0; text-align: justify; }
  table.sig { width: 100%; margin-top: 18px; border-collapse: collapse; }
  table.sig td { width: 50%; vertical-align: top; padding: 6px; height: 90px; border: 0.5px solid #cfd8dd; }
  .montant { font-size: 20pt; font-weight: bold; color: ' . $couleur . '; text-align: center; margin: 8px 0; }
  .cadre { border: 0.8px solid ' . $couleur . '; padding: 10px 12px; margin: 10px 0; }
  .petit { font-size: 8pt; color: #6b7b84; }
</style>';
    }

    private static function bandeau(array $e): string
    {
        $logo = "";
        if ($e["logo"]) {
            $mime = mime_content_type($e["logo"]) ?: "image/png";
            $logo = '<td width="110"><img src="data:' . $mime . ';base64,' . base64_encode(file_get_contents($e["logo"])) . '" style="height:52px;max-width:100px;" /></td>';
        }
        $coord = array_filter([config("agence.adresse"), config("agence.contact")]);
        return '<table class="bandeau"><tr>' . $logo . '<td><div class="agence">' . e(mb_strtoupper($e["nom"])) . '</div>'
            . '<div class="coord">' . e(implode(" — ", $coord)) . '</div></td>'
            . '<td align="right" class="coord">Édité le ' . now()->format("d/m/Y") . '</td></tr></table>'
            . '<div class="filet"></div>';
    }

    private static function cachet(): string
    {
        $fichier = storage_path("app/public/cachet-agence.png");
        return is_readable($fichier)
            ? '<img src="data:image/png;base64,' . base64_encode(file_get_contents($fichier)) . '" style="height:70px;" />'
            : "";
    }

    /** Un reglage de l'agence pour le contrat. */
    private static function reglage(string $cle, string $defaut = ""): string
    {
        $v = \Illuminate\Support\Facades\DB::table("reglages_agence")->where("cle", $cle)->value("valeur");
        return trim((string) ($v ?? $defaut));
    }

    /** Nom en arabe s'il est connu, sinon en caracteres latins. */
    private static function nomArabe($personne): string
    {
        $ar = trim(($personne->first_name_ar ?? "") . " " . ($personne->last_name_ar ?? ""));
        return $ar !== "" ? $ar : static::nom($personne);
    }

    private const RANGS = ["الأول", "الثاني", "الثالث", "الرابع", "الخامس", "السادس", "السابع", "الثامن", "التاسع", "العاشر", "الحادي عشر", "الثاني عشر"];

    /**
     * Le contrat de bail, en arabe, sur le modele de l'agence : l'agence
     * (mandataire du proprietaire) loue le logement au locataire.
     */
    public static function pdfBail(Bail $bail): string
    {
        $bail->loadMissing(["bien.city", "locataire"]);
        $e = RapportFinancier::entete();
        $c = "#" . $e["couleur"];
        $bien = $bail->bien;
        $loc = $bail->locataire;

        $mpdf = static::mpdf();
        $mpdf->SetDirectionality("rtl");
        $mpdf->SetHTMLFooter('<table width="100%" style="font-size:8pt;color:#6b7b84;border-top:0.4px solid #d5dde2;" dir="rtl"><tr>'
            . '<td>عقد رقم ' . $bail->id . ' — توقيع الطرفين : ............ / ............</td>'
            . '<td align="left">{PAGENO} / {nbpg}</td></tr></table>');

        $d = fn($x) => $x ? Carbon::parse($x)->format("Y/m/d") : "";
        // Un texte en lettres latines garde son sens de lecture au milieu de l'arabe.
        $t = fn($x) => preg_match('/\p{Arabic}/u', (string) $x) ? e($x) : '<span dir="ltr">' . e($x) . '</span>';
        $m = fn($x) => number_format((float) $x, 0, ",", " ");
        $societe = static::reglage("bail_societe", "الشركة العقارية ALWED LH");
        $representant = static::reglage("bail_representant");
        $cinRep = static::reglage("bail_representant_cin");
        $adrRep = static::reglage("bail_representant_adresse");
        $ville = static::reglage("bail_ville", "أكادير");

        $nationalite = in_array(strtoupper((string) ($loc->country_code ?? "")), ["", "MA", "212"], true) ? "، المغربي(ة) الجنسية" : "";
        $partie2 = "السيد(ة) <b>" . $t(static::nomArabe($loc)) . "</b>"
            . (($loc->identity_number ?? "") !== "" ? "، الحامل(ة) لبطاقة التعريف الوطنية رقم <b>" . e($loc->identity_number) . "</b>" : "")
            . $nationalite
            . (($loc->address ?? "") !== "" ? "، والساكن(ة) ب" . $t($loc->address) : "")
            . (($loc->tel ?? "") !== "" ? "، الهاتف : <span dir=\"ltr\">" . e(Telephone::local($loc->tel)) . "</span>" : "");

        $colocs = collect(is_array($bail->colocataires) ? $bail->colocataires : (json_decode((string) $bail->colocataires, true) ?: []))
            ->filter(fn($x) => trim((string) ($x["nom"] ?? "")) !== "");
        $htmlColocs = "";
        if ($colocs->isNotEmpty()) {
            $htmlColocs = '<p class="coloc">ويقيم معه بالمحل :</p><ul>' . $colocs->map(fn($x) => "<li>" . $t($x["nom"])
                . (($x["cin"] ?? "") !== "" ? " — ب.ت.و رقم : " . $t($x["cin"]) : "")
                . (($x["lien"] ?? "") !== "" ? " — الصفة : " . $t($x["lien"]) : "")
                . (($x["tel"] ?? "") !== "" ? " — الهاتف : <span dir=\"ltr\">" . e($x["tel"]) . "</span>" : "") . "</li>")->implode("") . "</ul>";
        }

        $consistance = array_filter([
            $bien?->nb_rooms ? $bien->nb_rooms . " غرف" : null,
            $bien?->nb_bathroom ? $bien->nb_bathroom . " حمام" : null,
            $bien?->surface ? "مساحة " . $bien->surface . " م²" : null,
            ($bien?->etage !== null && $bien?->etage !== "") ? "بالطابق " . $bien->etage : null,
        ]);
        $adresseBien = trim(($bien->address ?? "") . " " . ($bien->city->name ?? ""));
        $jour = Carbon::parse($bail->date_debut)->day;

        $fusl = [];
        $fusl[] = "لقد أكرى الطرف الأول بمقتضى هذا العقد للطرف الثاني المذكور أعلاه الشقة المسماة «<b>" . $t($bien->title ?? "") . "</b>»، الكائنة ب" . $t($adresseBien)
            . ($consistance ? "، والمتكونة من " . e(implode("، ", $consistance)) : "")
            . "، مع عداد للماء وعداد للكهرباء، وذلك قصد استعمالها للسكنى.";
        $fusl[] = "إن مدة هذا العقد محددة في <b>" . (int) $bail->duree_mois . " أشهر</b>، تبتدئ بتاريخ <b>" . $d($bail->date_debut) . "</b> وتنتهي بحلول <b>" . $d($bail->date_fin) . "</b>، "
            . "ويلتزم المكتري بعدم تولية المحل للغير وبتسليم مفاتيحه للمكري وحده عند انتهاء مدة العقد، كما يلتزم بأن يحافظ على العين المكراة وبإرجاعها على الحالة التي تسلمها عليها.";
        $fusl[] = "اتفق الطرفان على تحديد السومة الكرائية الشهرية للعين المكراة في مبلغ <b>" . $m($bail->loyer) . " درهم</b> (<span dir=\"ltr\">" . $m($bail->loyer) . " DH</span>)"
            . ((float) $bail->charges > 0 ? "، بالإضافة إلى <b>" . $m($bail->charges) . " درهم</b> كتحملات شهرية، أي ما مجموعه <b>" . $m($bail->montantMensuel()) . " درهم</b> في الشهر" : "")
            . "، تؤدى مسبقاً في اليوم " . $jour . " من كل شهر لدى الطرف الأول، بدون أي مماطلة أو تأخير، مع أداء واجب استهلاك الكهرباء والماء.";
        if ((float) $bail->depot > 0) {
            $fusl[] = "دفع المكتري للطرف الأول مبلغ <b>" . $m($bail->depot) . " درهم</b> على سبيل الضمانة، يُرد إليه عند انتهاء العقد بعد معاينة المحل والتأكد من أداء جميع الواجبات (الكراء، الماء، الكهرباء، والإصلاحات إن وجدت).";
        }
        $fusl[] = "في حالة إرادة المكتري إفراغ المحل موضوع هذا العقد وجب عليه إشعار المكري قبل شهر من تاريخ الرحيل، مع أداء جميع الواجبات.";
        $compteurs = array_filter([
            $bail->compteur_eau_entree ? "عداد الماء : " . e($bail->compteur_eau_entree) : null,
            $bail->compteur_elec_entree ? "عداد الكهرباء : " . e($bail->compteur_elec_entree) : null,
        ]);
        $fusl[] = "يقر المكتري بمعرفته المحل وبقبوله على ما هو عليه، ويشهد بتسلمه العين المكراة في حالة جيدة"
            . ($compteurs ? "، وقد سجل عند التسليم : " . implode("، ", $compteurs) : "") . ".";
        $fusl[] = "لا يمكن للمكتري استعمال المحل لغير ما اتفق عليه إلا بموافقة المكري، كما يلتزم باحترام الجيران وأن لا يصدر منه ما يزعجهم ويقلقهم.";
        $fusl[] = "كل ما يدخله المكتري على المحل موضوع الكراء من تحسينات أو إصلاحات أو غيرها فهو على نفقته الخاصة، ولا يمكنه مطالبة المكري بأي تعويض إلا إذا اتفقا على ذلك مسبقاً بواسطة وثيقة مكتوبة.";

        $htmlFusl = "";
        foreach ($fusl as $i => $texte) {
            $htmlFusl .= '<p class="fasl"><span class="rang">الفصل ' . (static::RANGS[$i] ?? ($i + 1)) . ' :</span> ' . $texte . '</p>';
        }

        $logo = "";
        if ($e["logo"]) {
            $mime = mime_content_type($e["logo"]) ?: "image/png";
            $logo = '<img src="data:' . $mime . ';base64,' . base64_encode(file_get_contents($e["logo"])) . '" style="height:62px;" />';
        }

        $html = '<style>
  body { font-family: traditionalarabic, xbriyaz, sans-serif; font-size: 15pt; color: #16242b; line-height: 1.55; }
  .cadre { border: 1.2px solid ' . $c . '; padding: 10px 16px; }
  table.tete { width: 100%; border-collapse: collapse; }
  .societe { font-size: 13pt; font-weight: bold; color: ' . $c . '; }
  .titre { text-align: center; font-size: 26pt; font-weight: bold; color: ' . $c . '; margin: 6px 0 0 0; }
  .sous { text-align: center; font-size: 13pt; color: #4d5e67; margin-bottom: 4px; }
  .ref { text-align: center; font-size: 10pt; color: #6b7b84; }
  .filet { height: 2px; background: ' . $c . '; margin: 8px 0; }
  .partie { margin: 4px 0; text-align: justify; }
  .qualite { text-align: left; font-weight: bold; color: ' . $c . '; margin: 0 0 6px 0; }
  .accord { font-weight: bold; margin: 8px 0 4px 0; }
  .fasl { text-align: justify; margin: 5px 0; }
  .rang { font-weight: bold; color: ' . $c . '; }
  .coloc { font-weight: bold; margin: 4px 0 0 0; }
  ul { margin: 2px 0 6px 0; }
  .note { background: #f2f7f8; padding: 6px 10px; margin: 8px 0; }
  .final { text-align: justify; margin-top: 8px; }
  .lieu { text-align: left; margin: 8px 0 4px 0; font-weight: bold; }
  table.sig { width: 100%; border-collapse: collapse; margin-top: 6px; }
  table.sig td { width: 50%; text-align: center; vertical-align: top; padding: 6px; height: 95px; font-weight: bold; }
</style>
<div class="cadre" dir="rtl">
<table class="tete"><tr><td style="text-align:right"><div class="societe">' . e($societe) . '</div><div style="font-size:10pt;color:#5b6b73">' . e(config("agence.adresse", "")) . '</div></td>'
            . '<td style="text-align:left" width="120">' . $logo . '</td></tr></table>
<div class="titre">عقد كراء</div>
<div class="sous">محل معد للسكنى</div>
<div class="ref">عقد رقم ' . $bail->id . ' — حرر بتاريخ ' . $d($bail->created_at) . '</div>
<div class="filet"></div>
<p class="accord">بين الموقعين أسفله :</p>
<p class="partie"><span class="rang">الطرف الأول :</span> ' . e($societe)
            . ($representant !== "" ? "، المتمثلة قانونيا في شخص " . e($representant) . "، مغربي الجنسية" : "")
            . ($cinRep !== "" ? "، الحامل لبطاقة التعريف الوطنية رقم " . e($cinRep) : "")
            . ($adrRep !== "" ? "، الساكن ب" . e($adrRep) : "") . '.</p>
<p class="qualite">بصفته مكري</p>
<p class="partie"><span class="rang">الطرف الثاني :</span> ' . $partie2 . '.</p>' . $htmlColocs . '
<p class="qualite">بصفته مكتري</p>
<p class="accord">لقد وقع الاتفاق والتراضي على ما يلي :</p>
' . $htmlFusl
            . ($bail->remarques ? '<div class="note"><b>ملاحظة :</b> ' . (preg_match('/\p{Arabic}/u', (string) $bail->remarques) ? nl2br(e($bail->remarques)) : '<span dir="ltr">' . nl2br(e($bail->remarques)) . '</span>') . '</div>' : '') . '
<p class="final">كل ما لم ينص عليه هذا العقد فهو خاضع لمقتضيات القانون الكرائي الجاري به العمل (القانون رقم 67.12).</p>
<p class="final">وبصحة ما ذكر أعلاه يمضي كل من الطرفين أسفله بعلامة يده، دلالة على الصدق والوفاء، بعدما حرر لهما بحسن نية وبحضورهما معا وقرئ عليهما بالحرف التام.</p>
<p class="lieu">وحرر في ' . e($ville) . ' بتاريخ ' . $d($bail->created_at) . '</p>
<table class="sig"><tr><td>إمضاء الطرف الأول (المكري)<br/>' . static::cachet() . '</td><td>إمضاء الطرف الثاني (المكتري)</td></tr></table>
</div>';

        return static::rendre($mpdf, $html);
    }

    public static function pdfQuittance(LoyerPaiement $paiement): string
    {
        $paiement->loadMissing(["loyer", "bail.bien.city", "bail.locataire", "manager"]);
        $e = RapportFinancier::entete();
        $c = "#" . $e["couleur"];
        $loyer = $paiement->loyer;
        $bail = $paiement->bail;
        $bien = $bail->bien;
        $loc = $bail->locataire;

        $mpdf = static::mpdf();
        $ligne = fn($l, $v) => '<tr><td class="l">' . e($l) . '</td><td class="v">' . e($v) . '</td></tr>';
        $reste = $loyer->reste();

        $html = static::style($c) . static::bandeau($e)
            . '<div class="titre">QUITTANCE DE LOYER</div>'
            . '<div class="titre-ar">وصل أداء الكراء</div>'
            . '<div class="ref">Quittance n° ' . $paiement->id . ' — ' . e($loyer->libelle()) . '</div>'
            . '<div class="cadre"><div class="montant">' . static::montant($paiement->montant) . ' MAD</div>'
            . '<p style="text-align:center">reçus de <b>' . e(static::nom($loc)) . '</b> le ' . static::date($paiement->paye_le)
            . ' (' . e(LoyerPaiement::MODES[$paiement->mode] ?? $paiement->mode) . ')</p></div>'
            . '<table class="fiche">'
            . $ligne("Logement", trim(($bien->title ?? "") . " — " . ($bien->address ?? "") . " " . ($bien->city->name ?? "")))
            . $ligne("Période", "Du " . static::date($loyer->periode_debut) . " au " . static::date($loyer->periode_fin))
            . $ligne("Montant de l'échéance", static::montant($loyer->montant) . " MAD")
            . $ligne("Total réglé pour la période", static::montant($loyer->paye) . " MAD")
            . $ligne("Reste à payer", $reste > 0 ? static::montant($reste) . " MAD" : "Néant — période soldée")
            . ($paiement->reference ? $ligne("Référence", $paiement->reference) : "")
            . $ligne("Encaissé par", static::nom($paiement->manager) ?: $e["nom"])
            . '</table>'
            . '<p class="petit" style="margin-top:10px;">' . ($reste > 0
                ? "Reçu à titre d'acompte : la quittance ne vaut libération que pour la somme indiquée."
                : "Cette quittance annule tous les reçus qui auraient pu être établis pour la même période.") . '</p>'
            . '<table class="sig"><tr><td style="border:none"></td><td><b>Pour l\'agence</b><br/>' . static::cachet() . '</td></tr></table>';

        return static::rendre($mpdf, $html);
    }

    /** Refait le contrat du bail et le range avec le bail ; renvoie son adresse. */
    public static function enregistrerContrat(Bail $bail): string
    {
        if (!static::$documentsActifs) {
            return "https://exemple.invalid/bail.pdf";
        }
        $bail->addMediaFromString(static::pdfBail($bail))
            ->usingFileName("bail-" . $bail->id . "-" . time() . ".pdf")
            ->toMediaCollection("contrat");
        return $bail->fresh()->getFirstMediaUrl("contrat");
    }

    public static function enregistrerQuittance(LoyerPaiement $paiement): string
    {
        if (!static::$documentsActifs) {
            return "https://exemple.invalid/quittance.pdf";
        }
        $paiement->addMediaFromString(static::pdfQuittance($paiement))
            ->usingFileName("quittance-" . $paiement->id . "-" . time() . ".pdf")
            ->toMediaCollection("quittance");
        return $paiement->fresh()->getFirstMediaUrl("quittance");
    }

    // ------------------------------------------------------------------
    // WhatsApp
    // ------------------------------------------------------------------

    public static function variables(Bail $bail, ?Loyer $loyer = null, ?LoyerPaiement $paiement = null): array
    {
        $bail->loadMissing(["bien.city", "locataire"]);
        $bien = $bail->bien;
        return [
            "{client_name}"    => static::nom($bail->locataire),
            "{apartment_name}" => $bien->title ?? "",
            "{address}"        => trim(($bien->address ?? "") . " " . ($bien->city->name ?? "")),
            "{start_date}"     => static::date($bail->date_debut),
            "{end_date}"       => static::date($bail->date_fin),
            "{rent}"           => number_format($bail->montantMensuel(), 0, ",", " "),
            "{deposit}"        => number_format((float) $bail->depot, 0, ",", " "),
            "{period}"         => $loyer ? $loyer->libelle() : "",
            "{due_date}"       => $loyer ? static::date($loyer->echeance) : "",
            "{amount}"         => number_format((float) ($paiement ? $paiement->montant : ($loyer?->montant ?? 0)), 0, ",", " "),
            "{balance}"        => $loyer ? number_format($loyer->reste(), 0, ",", " ") : "",
            "{contact}"        => (string) config("agence.contact", ""),
        ];
    }

    /**
     * Envoie un document au locataire. Renvoie null si c'est parti,
     * sinon la raison de l'echec.
     */
    public static function envoyerDocument(Bail $bail, string $url, string $modele, array $variables, string $fichier): ?string
    {
        $numero = Telephone::international($bail->locataire->tel ?? "");
        if ($numero === "") {
            return "Le locataire n'a pas de numéro de téléphone valide.";
        }
        if (!static::$envoisActifs) {
            return null;
        }
        try {
            $wa = new WasenderClient(config("services.whatsapp.wasender_key"));
            $wa->sendDocument($numero, $url, ModelesMessages::rendu($modele, $variables), $fichier);
            return null;
        } catch (Throwable $th) {
            Log::error("Envoi WhatsApp bail {$bail->id} : " . $th->getMessage());
            return "L'envoi WhatsApp a échoué. Réessayez plus tard.";
        }
    }

    public static function envoyerTexte(string $numero, string $texte): void
    {
        if (!static::$envoisActifs) {
            return;
        }
        $wa = new WasenderClient(config("services.whatsapp.wasender_key"));
        $wa->sendText($numero, $texte);
    }
}
