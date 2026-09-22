<?php

namespace App\Services;

use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Mpdf\Mpdf;

/**
 * Documents de la vente, en arabe, sur le papier de l'agence : le mandat
 * de vente confie par le proprietaire (عقد وساطة عقارية) et le recu de
 * visite signe par l'acheteur (وصل زيارة عقار).
 */
class DocumentsVente
{
    public const TYPES = [
        "appartement" => "شقة", "villa" => "فيلا", "immeuble" => "عمارة", "maison" => "منزل",
        "terrain" => "أرض", "local" => "محل تجاري", "bureau" => "مكتب", "riad" => "رياض",
    ];

    public static function reglage(string $cle, string $defaut = ""): string
    {
        $v = DB::table("reglages_agence")->where("cle", $cle)->value("valeur");
        return trim((string) ($v ?? $defaut));
    }

    /** Le type du bien en arabe, depuis sa categorie. */
    public static function typeArabe($bien): string
    {
        $cat = mb_strtolower((string) ($bien?->category?->name ?? $bien?->category?->title ?? ""));
        foreach (self::TYPES as $fr => $ar) {
            if ($cat !== "" && str_contains($cat, $fr)) return $ar;
        }
        return "شقة";
    }

    private static function mpdf(): Mpdf
    {
        ini_set("pcre.backtrack_limit", "50000000");
        $mpdf = new Mpdf(array_merge(is_array(config("pdf.polices")) ? config("pdf.polices") : [], [
            "mode" => "utf-8", "format" => "A4", "orientation" => "P",
            "margin_left" => 18, "margin_right" => 18, "margin_top" => 16, "margin_bottom" => 36, "margin_footer" => 0,
            "autoScriptToLang" => true, "autoLangToFont" => true,
        ]));
        $mpdf->SetDirectionality("rtl");
        $filigrane = resource_path("views/pdf/assets/alwed-filigrane.png");
        if (is_readable($filigrane)) {
            $mpdf->SetWatermarkImage($filigrane, 0.55, [120, 155], [45, 70]);
            $mpdf->showWatermarkImage = true;
            $mpdf->watermarkImgBehind = true;
        }
        $couleur = "#3AAFB9";
        $ice = static::reglage("entete_ice");
        $adresse = static::reglage("entete_adresse");
        $mpdf->SetHTMLFooter('
<div style="padding:0 16mm;" dir="ltr">
  <table width="100%" style="border-top:1.4px solid #9aa4aa;font-family:sans-serif;font-size:9pt;color:#555;"><tr>
    <td style="padding-top:4px;text-align:left;">' . ($ice ? "ICE : " . e($ice) . "<br/>" : "") . ($adresse ? "ADRESSE : " . e($adresse) : "") . '</td>
  </tr></table>
</div>
<table width="100%" dir="ltr" style="background:' . $couleur . ';color:#fff;font-family:sans-serif;font-size:9pt;"><tr>
  <td style="padding:6px 16mm;text-align:left;">' . e(static::reglage("entete_reseaux")) . '</td>
  <td align="center">' . e(static::reglage("entete_email")) . '</td>
  <td style="padding-right:16mm;text-align:right;">' . e(static::reglage("entete_tel")) . '</td>
</tr></table>');
        return $mpdf;
    }

    private static function style(): string
    {
        return '<style>
  body { font-family: traditionalarabic, xbriyaz, sans-serif; font-size: 16pt; color: #1b1b1b; line-height: 1.6; }
  .titre { text-align: center; font-size: 28pt; font-weight: bold; text-decoration: underline; margin: 4mm 0 8mm 0; }
  .lbl { font-weight: bold; text-decoration: underline; }
  .bloc { margin: 3mm 0; text-align: justify; }
  .ligne { margin: 0 0 1mm 0; }
  .engagement { font-weight: bold; font-style: normal; font-size: 17pt; text-align: justify; margin: 5mm 0 3mm 0; }
  ol { margin: 2mm 0; }
  table.sig { width: 100%; margin-top: 12mm; border-collapse: collapse; }
  table.sig td { width: 50%; text-align: center; font-weight: bold; vertical-align: top; height: 32mm; }
</style>';
    }

    private static function rendre(Mpdf $mpdf, string $html): string
    {
        set_error_handler(fn() => true, E_WARNING | E_NOTICE | E_DEPRECATED | E_USER_WARNING | E_USER_NOTICE);
        try {
            $mpdf->WriteHTML(static::style() . '<div dir="rtl">' . $html . '</div>');
            return $mpdf->Output("", "S");
        } finally {
            restore_error_handler();
        }
    }

    /** Un texte en lettres latines garde son sens de lecture au milieu de l'arabe. */
    public static function t($x): string
    {
        $x = (string) $x;
        if ($x === "") return "..........";
        return preg_match('/\p{Arabic}/u', $x) ? e($x) : '<span dir="ltr">' . e($x) . '</span>';
    }

    private static function cachet(): string
    {
        $f = storage_path("app/public/cachet-agence.png");
        return is_readable($f) ? '<img src="data:image/png;base64,' . base64_encode(file_get_contents($f)) . '" style="height:24mm;" />' : "";
    }

    /** La signature dessinee par le proprietaire, avec sa date. */
    private static function signature(object $m): string
    {
        if (empty($m->signature)) return "";
        $f = storage_path("app/private/" . $m->signature);
        if (!is_readable($f)) $f = storage_path("app/" . $m->signature);
        if (!is_readable($f)) return "";
        return '<img src="data:image/png;base64,' . base64_encode(file_get_contents($f)) . '" style="height:22mm;" />'
            . (!empty($m->signe_le) ? '<br/><span style="font-size:10pt;font-weight:normal;">وقع بتاريخ ' . Carbon::parse($m->signe_le)->format("Y/m/d") . '</span>' : "");
    }

    private static function nombre($v): string
    {
        // Pas d'espaces : au milieu de l'arabe, ils inverseraient l'ordre des groupes.
        $s = rtrim(rtrim(number_format((float) $v, 2, ".", ","), "0"), ".");
        return '<span dir="ltr">' . $s . '</span>';
    }

    public static function pdfMandat(object $m): string
    {
        $t = [static::class, "t"];
        $societe = static::reglage("bail_societe", "الشركة العقارية ALWED LH");
        $rep = static::reglage("bail_representant", "السيد هشام لوريدة");
        $cinRep = static::reglage("bail_representant_cin");
        $siege = static::reglage("entete_adresse_ar", "حي السلام زنقة اكلو رقم 36 أكادير");
        $date = Carbon::parse($m->date_signature)->format("Y/m/d");
        $duree = (int) $m->duree_mois;
        $dureeTexte = $duree === 12 ? "سنة كاملة" : ($duree . " أشهر");

        $html = '<div class="titre">عـقـد وساطة عقارية</div>
<p class="bloc"><u>بين الموقعين أسفله :</u></p>
<p class="bloc"><span class="lbl">الطرف الأول :</span> السيد(ة) ' . $t($m->proprietaire_nom)
            . '، الحامل(ة) لبطاقة التعريف الوطنية رقم ' . $t($m->proprietaire_cin)
            . '، ' . ($m->proprietaire_nationalite ? $t($m->proprietaire_nationalite) . ' الجنسية' : 'المغربي(ة) الجنسية')
            . '، القاطن(ة) ب' . $t($m->proprietaire_adresse) . '.</p>
<p class="ligne">رقم الهاتف : ' . $t($m->proprietaire_tel) . '</p>
<p class="bloc">حيث أمتلك عقاراً من نوع ' . $t($m->type_bien) . ' ب' . $t($m->ville ?: "أكادير") . '، معلوماته كالتالي :</p>
<p class="ligne">مساحته : ' . ($m->surface ? static::nombre($m->surface) : "..........") . ' متر مربع</p>
<p class="ligne">رقم الرسم العقاري : ' . $t($m->titre_foncier) . '</p>
<p class="ligne">عنوانه : ' . $t($m->adresse_bien) . '.</p>'
            . ($m->prix_demande ? '<p class="ligne">الثمن المطلوب : ' . static::nombre($m->prix_demande) . ' درهم</p>' : '') . '
<p class="bloc" style="margin-top:6mm;"><span class="lbl">الطرف الثاني :</span> ' . $t($societe) . '، مقرها الرئيسي ' . $t($siege)
            . '، الممثلة قانونيا في شخص ' . $t($rep) . ' مغربي الجنسية' . ($cinRep ? '، الحامل لبطاقة التعريف الوطنية رقم ' . $t($cinRep) : '') . '.</p>
<p class="bloc">حرر على حسن النية وإدراك تام بتاريخ ' . $date . '.</p>
<p class="bloc" style="margin-top:5mm;">بناءً على ذلك فإن الطرف الأول (المالك) يكلف ' . $t($societe) . ' للوساطة ببيع العقار المذكور أعلاه.</p>
<p class="bloc">وأيضاً فيما يلي :</p>
<ol>
  <li>تكون مدة هذا التكليف ' . $dureeTexte . ' من تاريخ التوقيع (' . $date . ').</li>
  <li>نسبة أجرة الشركة من هذا البيع هي ' . static::nombre($m->commission) . '%، تستلمها الشركة عند إبرام العقد.</li>
  <li>يحق للشركة المطالبة بهذه النسبة إذا ثبت بيع العقار عن طريق شركة أخرى أو بطريقة من الطرق، خلال المدة المتفق عليها لبيع العقار.</li>
  <li>يحق للشركة المطالبة بأتعاب تسويق العقار في حالة تراجع الزبون عن البيع أو تغيير في سعر العقار دون سابق إنذار، أو عند إحضار زبون (شاري) وتم التقاعس عن البيع، ويلتزم الطرف الأول (المالك) بدفع أتعاب الشركة حسب المدة ومصروفات التسويق.</li>
</ol>'
            . ($m->remarques ? '<p class="bloc"><b>ملاحظة :</b> ' . $t($m->remarques) . '</p>' : '') . '
<table class="sig"><tr><td>إمضاء ممثل الشركة العقارية<br/>' . static::cachet() . '</td><td>إمضاء المالك<br/>' . static::signature($m) . '</td></tr></table>';

        return static::rendre(static::mpdf(), $html);
    }

    public static function pdfVisite(object $v, object $bien, ?object $mandat): string
    {
        $t = [static::class, "t"];
        $societe = static::reglage("bail_societe", "الشركة العقارية ALWED LH");
        $siege = static::reglage("entete_adresse_ar", "حي السلام زنقة اكلو رقم 36 أكادير");
        $date = Carbon::parse($v->date_visite)->format("Y/m/d");
        $type = $mandat->type_bien ?? static::typeArabe($bien);
        $ville = $mandat->ville ?? ($bien->city->name ?? "أكادير");
        $surface = $mandat->surface ?? $bien->surface ?? null;
        $titre = $mandat->titre_foncier ?? null;
        $adresse = $mandat->adresse_bien ?? trim(($bien->address ?? "") . " " . ($bien->city->name ?? ""));

        $html = '<div class="titre">وصل زيارة عقار</div>
<p class="bloc"><span class="lbl">الطرف الأول :</span> السيد(ة) ' . $t($v->visiteur_nom) . '، الحامل(ة) لبطاقة التعريف الوطنية رقم ' . $t($v->visiteur_cin)
            . '، جنسيته ' . $t($v->visiteur_nationalite ?: "مغربية") . '، القاطن(ة) ب' . $t($v->visiteur_adresse) . '.</p>
<p class="ligne">رقم الهاتف : ' . $t($v->visiteur_tel) . '</p>
<p class="bloc" style="margin-top:6mm;">أصرح بأنني قمت بزيارة العقار التالي بتنسيق مع <b><u>' . $t($societe) . '</u></b>، مقرها الرئيسي ' . $t($siege) . '، بتاريخ ' . $date . '.</p>
<p class="bloc" style="margin-top:5mm;">العقار من نوع ' . $t($type) . ' ب' . $t($ville) . '، معلوماته كالتالي :</p>
<p class="ligne">المساحة : ' . ($surface ? static::nombre($surface) : "..........") . ' متر مربع</p>
<p class="ligne">رقم شهادة الملكية : ' . $t($titre) . '</p>
<p class="ligne">عنوانه : ' . $t($adresse) . '.</p>
<p class="engagement">أُقر بأنني زرت العقار أعلاه بتنسيق مع الشركة العقارية، وأتعهد بعدم التواصل أو التفاوض مباشرة مع المالك أو أي طرف آخر بشأن هذا العقار دون موافقة الشركة، طيلة مدة صلاحية العرض، تحت طائلة المتابعة القانونية.</p>
<p class="engagement">في حالة إتمام عملية الشراء، ستكون عمولة الشركة ' . static::nombre($v->commission ?: ($mandat->commission ?? 2.5)) . '% من قيمة البيع، تؤدى يوم توقيع الوعد بالبيع أو العقد النهائي.</p>'
            . '
<table class="sig"><tr><td>إمضاء الزبون<br/>' . static::signature($v) . '</td><td>إمضاء الوكيل العقاري<br/>' . static::cachet() . '</td></tr></table>';

        // Le recu tient sur une page : l'ecriture se resserre s'il deborde.
        $pdf = static::rendre(static::mpdf(), $html);
        if (preg_match_all('#/Type\s*/Page[^s]#', $pdf) > 1) {
            $pdf = static::rendre(static::mpdf(), '<div style="font-size:13.5pt;line-height:1.45;">' . $html . '</div>');
        }
        return $pdf;
    }
}
