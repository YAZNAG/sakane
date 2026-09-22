<?php

namespace App\Http\Controllers\dashboard;

use App\Exports\TableauExport;
use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Maatwebsite\Excel\Facades\Excel;
use Mpdf\Mpdf;

/**
 * Exporte en Excel ou en PDF le tableau affiche par une page de
 * l'application.
 *
 * L'application envoie ce qu'elle montre : un titre, les colonnes et une
 * ligne par element. Un seul point d'entree sert toutes les pages ; le
 * document porte l'en-tete de l'agence (logo, nom), la periode et la
 * date d'export.
 */
class ExportController extends Controller
{
    public function generer(Request $request)
    {
        $validation = Validator::make($request->all(), [
            "format"     => ["required", "in:xlsx,pdf"],
            "titre"      => ["required", "string", "max:120"],
            "sousTitre"  => ["nullable", "string", "max:300"],
            "colonnes"   => ["required", "array", "min:1", "max:30"],
            "colonnes.*" => ["nullable", "string", "max:80"],
            "lignes"     => ["present", "array", "max:20000"],
            "lignes.*"   => ["array"],
            "totaux"     => ["nullable", "array"],
        ]);

        if ($validation->fails()) {
            return response()->json([
                "success"    => false,
                "statusCode" => 422,
                "message"    => $validation->errors()->first(),
            ], 422);
        }

        $titre     = trim((string) $request->input("titre"));
        $sousTitre = trim((string) $request->input("sousTitre", ""));
        $colonnes  = array_map(fn($c) => (string) ($c ?? ""), array_values($request->input("colonnes")));
        $largeur   = count($colonnes);

        // Chaque ligne a exactement le nombre de colonnes annonce : une
        // cellule manquante devient vide, une cellule en trop est ignoree.
        $normaliser = function ($ligne) use ($largeur) {
            $cellules = array_map(
                fn($x) => is_scalar($x) || $x === null ? (string) ($x ?? "") : json_encode($x, JSON_UNESCAPED_UNICODE),
                array_values((array) $ligne)
            );
            return array_slice(array_pad($cellules, $largeur, ""), 0, $largeur);
        };

        $lignes = array_map($normaliser, $request->input("lignes", []));
        $totaux = $request->filled("totaux") ? $normaliser($request->input("totaux")) : null;

        // Une case vide s'affiche « - » : on voit qu'il n'y a rien, et non un oubli.
        $tiret  = fn(array $l) => array_map(fn($v) => trim((string) $v) === "" ? "-" : $v, $l);
        $lignes = array_map($tiret, $lignes);
        if ($totaux !== null) {
            $totaux = $tiret($totaux);
        }

        $entete = $this->entete();
        $nom = (Str::slug($titre) ?: "export") . "_" . now()->format("Ymd_His");

        if ($request->input("format") === "xlsx") {
            return Excel::download(
                new TableauExport($titre, $sousTitre, $colonnes, $lignes, $totaux, $entete),
                $nom . ".xlsx"
            );
        }

        return response($this->pdf($titre, $sousTitre, $colonnes, $lignes, $totaux, $entete), 200, [
            "Content-Type"        => "application/pdf",
            "Content-Disposition" => 'attachment; filename="' . $nom . '.pdf"',
        ]);
    }

    /**
     * L'identite de l'agence pour l'en-tete : nom, logo (photo de profil
     * du compte agence) et couleur de l'application.
     */
    private function entete(): array
    {
        $agence = User::where("agence", "1")->first();
        // Le nom officiel de l'agence (AGENCE_NOM) l'emporte sur celui du compte.
        $nom = trim((string) config("agence.nom"));
        if ($nom === "") {
            $nom = trim(($agence->first_name ?? "") . " " . ($agence->last_name ?? ""));
        }
        if ($nom === "") {
            $nom = (string) config("app.name");
        }

        $logo = null;
        try {
            $media = $agence?->getFirstMedia("profile_photo");
            if ($media && is_readable($media->getPath())) {
                $logo = $media->getPath();
            }
        } catch (\Throwable $e) {
            $logo = null;
        }

        // Les couleurs des deux applications : le bleu de Godar, le cyan d'Alwed.
        $couleur = str_contains(strtolower((string) config("app.name")), "alwed") ? "0E7C86" : "1F5F8B";

        return ["nom" => $nom, "logo" => $logo, "couleur" => $couleur];
    }

    /** Le meme tableau, mis en page pour etre imprime. */
    private function pdf(string $titre, string $sousTitre, array $colonnes, array $lignes, ?array $totaux, array $entete): string
    {
        // Un long tableau depasse vite la limite par defaut de PCRE, que
        // mPDF utilise pour lire le HTML.
        ini_set("pcre.backtrack_limit", "50000000");

        $couleur = "#" . $entete["couleur"];
        $paysage = count($colonnes) > 5;

        $mpdf = new Mpdf([
            "mode"             => "utf-8",
            "format"           => "A4",
            "orientation"      => $paysage ? "L" : "P",
            "margin_left"      => 10,
            "margin_right"     => 10,
            "margin_top"       => 10,
            "margin_bottom"    => 16,
            "margin_footer"    => 6,
            "autoScriptToLang" => true,
            "autoLangToFont"   => true,
        ]);

        $mpdf->SetHTMLFooter(
            '<table width="100%" style="font-size:7.5pt;color:#6b7b84;border-top:0.4px solid #d5dde2;padding-top:3px;"><tr>'
            . '<td>' . e($entete["nom"]) . ' — ' . e($titre) . '</td>'
            . '<td align="right">Page {PAGENO} / {nbpg}</td></tr></table>'
        );

        $logo = "";
        if ($entete["logo"]) {
            $mime = mime_content_type($entete["logo"]) ?: "image/png";
            $logo = '<img src="data:' . $mime . ';base64,' . base64_encode(file_get_contents($entete["logo"]))
                . '" style="height:58px;max-width:120px;" />';
        }

        $numerique = fn(string $v) => $v !== "" && preg_match('/^[-+]?[\d\s]+([.,]\d+)?( ?(MAD|DH|%))?$/u', $v);

        $entetes = implode("", array_map(fn($c) => "<th>" . e($c) . "</th>", $colonnes));

        $corps = [];
        foreach ($lignes as $i => $ligne) {
            $cellules = implode("", array_map(
                fn($v) => '<td' . ($v === '-' ? ' class="vide-case"' : ($numerique($v) ? ' class="n"' : '')) . '>' . nl2br(e($v)) . '</td>',
                $ligne
            ));
            $corps[] = '<tr' . ($i % 2 ? ' class="p"' : '') . '>' . $cellules . '</tr>';
        }
        if (empty($lignes)) {
            $corps[] = '<tr><td colspan="' . count($colonnes) . '" class="vide">Aucune ligne a exporter.</td></tr>';
        }

        $pied = $totaux === null ? "" : '<tr class="t">' . implode("", array_map(
            fn($v) => '<td' . ($v === '-' ? ' class="vide-case"' : ($numerique($v) ? ' class="n"' : '')) . '>' . e($v) . '</td>',
            $totaux
        )) . '</tr>';

        $nombre = count($lignes);

        $html = '
<style>
  body { font-family: sans-serif; color: #17262e; }
  table.bandeau { width: 100%; border-collapse: collapse; margin-bottom: 4px; }
  table.bandeau td { vertical-align: middle; }
  .agence { font-size: 10pt; font-weight: bold; color: ' . $couleur . '; letter-spacing: 0.5px; }
  .titre { font-size: 17pt; font-weight: bold; color: #17262e; margin-top: 2px; }
  .sous { font-size: 9pt; color: #4a5b64; margin-top: 3px; }
  .meta { font-size: 8pt; color: #6b7b84; text-align: right; line-height: 1.5; }
  .pastille { background: ' . $couleur . '; color: #ffffff; padding: 3px 9px; border-radius: 10px; font-weight: bold; font-size: 8.5pt; }
  .filet { height: 3px; background: ' . $couleur . '; margin: 6px 0 10px 0; }
  table.t { width: 100%; border-collapse: collapse; font-size: 8.5pt; }
  table.t th { background: ' . $couleur . '; color: #ffffff; text-align: center; padding: 6px 6px; font-weight: bold; border: 0.3px solid ' . $couleur . '; }
  table.t td { padding: 5px 6px; border-bottom: 0.3px solid #dfe6ea; vertical-align: top; }
  table.t td.vide-case { text-align: center; color: #98a6ae; }
  table.t tr.p td { background: #f4f7f9; }
  table.t td.n { text-align: right; white-space: nowrap; }
  table.t tr.t td { font-weight: bold; background: #e6eef4; border-top: 1.2px solid ' . $couleur . '; border-bottom: 1.2px solid ' . $couleur . '; }
  td.vide { text-align: center; color: #6b7b84; padding: 16px; }
</style>
<table class="bandeau"><tr>
  ' . ($logo !== "" ? '<td width="130">' . $logo . '</td>' : '') . '
  <td>
    <div class="agence">' . e(mb_strtoupper($entete["nom"])) . '</div>
    <div class="titre">' . e($titre) . '</div>
    ' . ($sousTitre !== "" ? '<div class="sous">' . e($sousTitre) . '</div>' : '') . '
  </td>
  <td class="meta" width="170">
    <span class="pastille">' . $nombre . ' ligne' . ($nombre > 1 ? 's' : '') . '</span><br/>
    Exporté le ' . now()->format("d/m/Y") . '<br/>à ' . now()->format("H:i") . '
  </td>
</tr></table>
<div class="filet"></div>
<table class="t" repeat_header="1">
  <thead><tr>' . $entetes . '</tr></thead>
  <tbody>' . implode("", $corps) . $pied . '</tbody>
</table>';

        // La mise en forme de l'arabe emet parfois de simples avertissements
        // internes a mPDF ; en requete, Laravel les changerait en erreur et
        // l'export echouerait pour un nom ecrit en arabe.
        set_error_handler(fn() => true, E_WARNING | E_NOTICE | E_DEPRECATED | E_USER_WARNING | E_USER_NOTICE);
        try {
            $mpdf->WriteHTML($html);
            return $mpdf->Output("", "S");
        } finally {
            restore_error_handler();
        }
    }
}
