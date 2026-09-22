<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Services\RapportFinancier;
use App\utils\JsonResponses;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Mpdf\Mpdf;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use Throwable;
use WasenderApi\WasenderClient;

/**
 * Historique des contrats envoyes aux syndics : par mois et par jour,
 * detail de chaque envoi, telechargement d'une periode, renvoi.
 */
class HistoriqueSyndicController extends Controller
{
    use JsonResponses;

    public static $envoyeur = null;

    private const SOURCES = ["auto" => "Automatique", "manuel" => "Partage manuel", "renvoi" => "Renvoi", "prolongation" => "Prolongation", "raccourcissement" => "Raccourcissement"];
    private const STATUTS = ["envoye" => "Envoyé", "echec" => "Échec", "ignore" => "Non envoyé"];

    private function periode(Request $request): array
    {
        $du = $request->filled("du") ? Carbon::parse($request->input("du"))->startOfDay() : now()->subMonths(2)->startOfMonth();
        $au = $request->filled("au") ? Carbon::parse($request->input("au"))->endOfDay() : now()->endOfDay();
        return [$du, $au];
    }

    private function lignes(Request $request)
    {
        [$du, $au] = $this->periode($request);
        $q = DB::table("syndic_envois")
            ->leftJoin("syndics", "syndics.id", "=", "syndic_envois.syndic_id")
            ->leftJoin("managers", "managers.id", "=", "syndic_envois.envoye_par")
            ->whereBetween("syndic_envois.created_at", [$du, $au])
            ->orderByDesc("syndic_envois.created_at")
            ->select("syndic_envois.*", "syndics.nom as syndic_nom", "managers.first_name as par_prenom", "managers.last_name as par_nom");
        if ($request->filled("syndic")) {
            $q->where("syndic_envois.syndic_id", $request->input("syndic"));
        }
        if ($request->filled("statut")) {
            $q->where("syndic_envois.statut", $request->input("statut"));
        }
        $lignes = $q->get();
        $reservations = Booking::withTrashed()->with(["client", "realestate"])->whereIn("id", $lignes->pluck("booking_id")->filter()->unique())->get()->keyBy("id");

        return $lignes->map(function ($l) use ($reservations) {
            $b = $reservations[$l->booking_id] ?? null;
            return [
                "id"          => $l->id,
                "date"        => Carbon::parse($l->created_at)->toISOString(),
                "syndic"      => $l->syndic_id ? ["id" => $l->syndic_id, "nom" => $l->syndic_nom] : null,
                "telephone"   => $l->telephone,
                "statut"      => $l->statut,
                "statutLibelle" => self::STATUTS[$l->statut] ?? $l->statut,
                "erreur"      => $l->erreur,
                "source"      => $l->source ?? "auto",
                "sourceLibelle" => self::SOURCES[$l->source ?? "auto"] ?? $l->source,
                "envoyePar"   => trim(($l->par_prenom ?? "") . " " . ($l->par_nom ?? "")) ?: null,
                "message"     => $l->message,
                "reservation" => $b ? [
                    "id"       => $b->id,
                    "checkin"  => Carbon::parse($b->checkin)->toDateString(),
                    "checkout" => Carbon::parse($b->checkout)->toDateString(),
                    "client"   => trim(($b->client->first_name ?? "") . " " . ($b->client->last_name ?? "")),
                    "bien"     => $b->realestate->title ?? null,
                    "supprimee" => $b->deleted_at !== null,
                ] : null,
                "contratUrl"  => $b ? ($b->getFirstMediaUrl("contract-public") ?: null) : null,
            ];
        })->values();
    }

    public function index(Request $request)
    {
        $lignes = $this->lignes($request);
        [$du, $au] = $this->periode($request);

        $mois = $lignes->groupBy(fn($l) => substr($l["date"], 0, 7))->map(function ($envois, $cle) {
            $jours = $envois->groupBy(fn($l) => Carbon::parse($l["date"])->setTimezone(config("app.timezone"))->toDateString())
                ->map(fn($e, $jour) => [
                    "jour"    => $jour,
                    "libelle" => ucfirst(Carbon::parse($jour)->locale("fr")->isoFormat("dddd D MMMM")),
                    "total"   => $e->count(),
                    "envois"  => $e->values(),
                ])->values();
            return [
                "mois"    => $cle,
                "libelle" => ucfirst(Carbon::parse($cle . "-01")->locale("fr")->isoFormat("MMMM YYYY")),
                "total"   => $envois->count(),
                "envoyes" => $envois->where("statut", "envoye")->count(),
                "echecs"  => $envois->where("statut", "echec")->count(),
                "jours"   => $jours,
            ];
        })->values();

        return $this->successResponse([
            "du"      => $du->toDateString(),
            "au"      => $au->toDateString(),
            "total"   => $lignes->count(),
            "envoyes" => $lignes->where("statut", "envoye")->count(),
            "echecs"  => $lignes->where("statut", "echec")->count(),
            "ignores" => $lignes->where("statut", "ignore")->count(),
            "mois"    => $mois,
        ]);
    }

    public function show(Request $request, $id)
    {
        $r = $request->duplicate(["du" => "2000-01-01", "au" => now()->addDay()->toDateString()]);
        $l = $this->lignes($r)->firstWhere("id", (int) $id);
        return $l ? $this->successResponse($l) : $this->notFoundResponse("Envoi introuvable");
    }

    /** Telecharge l'historique d'une periode, en PDF ou en Excel. */
    public function export(Request $request)
    {
        $v = Validator::make($request->all(), ["format" => ["nullable", "in:pdf,xlsx"], "du" => ["nullable", "date"], "au" => ["nullable", "date"]]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());
        $lignes = $this->lignes($request)->reverse()->values();
        [$du, $au] = $this->periode($request);
        $titre = "Envois au syndic du " . $du->format("d/m/Y") . " au " . $au->format("d/m/Y");
        $colonnes = ["Date", "Heure", "Syndic", "Téléphone", "Bien", "Client", "Séjour", "Envoi", "Statut", "Par"];
        $data = $lignes->map(function ($l) {
            $d = Carbon::parse($l["date"])->setTimezone(config("app.timezone"));
            $r = $l["reservation"];
            return [$d->format("d/m/Y"), $d->format("H:i"), $l["syndic"]["nom"] ?? "-", $l["telephone"] ?? "-", $r["bien"] ?? "-", $r["client"] ?? "-",
                $r ? Carbon::parse($r["checkin"])->format("d/m") . " → " . Carbon::parse($r["checkout"])->format("d/m/Y") : "-",
                $l["sourceLibelle"], $l["statutLibelle"] . ($l["erreur"] ? " (" . mb_substr($l["erreur"], 0, 60) . ")" : ""), $l["envoyePar"] ?? "-"];
        })->all();
        $nom = "envois_syndic_" . $du->format("Ymd") . "_" . $au->format("Ymd");

        if ($request->input("format") === "xlsx") {
            $x = new Spreadsheet();
            $f = $x->getActiveSheet();
            $f->setTitle("Envois");
            $f->setCellValue("A1", $titre);
            $f->getStyle("A1")->getFont()->setBold(true)->setSize(13);
            $f->fromArray($colonnes, null, "A3");
            $f->getStyle("A3:J3")->getFont()->setBold(true);
            $f->fromArray($data, null, "A4");
            foreach (range("A", "J") as $col) $f->getColumnDimension($col)->setAutoSize(true);
            $base = tempnam(sys_get_temp_dir(), "syn_");
            @unlink($base);
            (new Xlsx($x))->save($base . ".xlsx");
            return response()->download($base . ".xlsx", $nom . ".xlsx")->deleteFileAfterSend(true);
        }

        $e = RapportFinancier::entete();
        $c = "#" . $e["couleur"];
        $mpdf = new Mpdf(array_merge(is_array(config("pdf.polices")) ? config("pdf.polices") : [], [
            "mode" => "utf-8", "format" => "A4", "orientation" => "L", "margin_left" => 10, "margin_right" => 10,
            "margin_top" => 10, "margin_bottom" => 14, "autoScriptToLang" => true, "autoLangToFont" => true,
        ]));
        $mpdf->SetHTMLFooter('<div style="font-size:8pt;color:#6b7b84;text-align:right">Page {PAGENO} / {nbpg}</div>');
        $corps = "";
        $jourPrecedent = null;
        foreach ($data as $ligne) {
            if ($ligne[0] !== $jourPrecedent) {
                $corps .= '<tr><td colspan="9" style="background:#e6eef4;font-weight:bold;padding:4px">' . e($ligne[0]) . '</td></tr>';
                $jourPrecedent = $ligne[0];
            }
            $corps .= "<tr>" . implode("", array_map(fn($v) => "<td>" . e($v) . "</td>", array_slice($ligne, 1))) . "</tr>";
        }
        $html = '<style>body{font-family:sans-serif;font-size:9pt} h1{font-size:15pt;color:' . $c . ';margin:0 0 2px 0}
            table{width:100%;border-collapse:collapse} th{background:' . $c . ';color:#fff;padding:5px;font-size:8.5pt}
            td{padding:4px;border-bottom:0.3px solid #dfe6ea}</style>'
            . '<div style="font-weight:bold;color:' . $c . '">' . e(mb_strtoupper($e["nom"])) . '</div><h1>' . e($titre) . '</h1>'
            . '<div style="margin-bottom:6px;color:#555">' . count($data) . ' envoi(s) — ' . $lignes->where("statut", "envoye")->count() . ' envoyé(s), '
            . $lignes->where("statut", "echec")->count() . ' échec(s)</div>'
            . '<table><thead><tr>' . implode("", array_map(fn($x) => "<th>" . e($x) . "</th>", array_slice($colonnes, 1))) . '</tr></thead><tbody>'
            . ($corps ?: '<tr><td colspan="9" style="text-align:center;padding:14px">Aucun envoi sur cette période.</td></tr>') . '</tbody></table>';
        set_error_handler(fn() => true, E_WARNING | E_NOTICE | E_DEPRECATED);
        try {
            $mpdf->WriteHTML($html);
            $pdf = $mpdf->Output("", "S");
        } finally {
            restore_error_handler();
        }
        return response($pdf, 200, ["Content-Type" => "application/pdf", "Content-Disposition" => 'attachment; filename="' . $nom . '.pdf"']);
    }

    /** Renvoie le meme contrat, avec le meme message, au meme numero. */
    public function renvoyer(Request $request, $id)
    {
        $l = DB::table("syndic_envois")->find($id);
        if (!$l) return $this->notFoundResponse("Envoi introuvable");
        $b = Booking::withTrashed()->find($l->booking_id);
        $contrat = $b?->getFirstMediaUrl("contract-public");
        if (!$b || !$contrat) {
            return $this->validationErrorResponse(["msg" => ["Le contrat de cette réservation n'est plus disponible."]]);
        }
        if (empty($l->telephone)) {
            return $this->validationErrorResponse(["msg" => ["Cet envoi n'a pas de numéro de téléphone."]]);
        }
        $message = $l->message ?: \App\Services\EnvoiSyndic::message($b, $l->syndic_id ? \App\Models\Syndic::find($l->syndic_id) : null);
        $statut = "envoye";
        $erreur = null;
        try {
            if (is_callable(static::$envoyeur)) {
                (static::$envoyeur)($l->telephone, $contrat, $message);
            } else {
                (new WasenderClient(config("services.whatsapp.wasender_key")))->sendDocument($l->telephone, $contrat, $message, "contrat_location.pdf");
            }
        } catch (Throwable $th) {
            $statut = "echec";
            $erreur = mb_substr($th->getMessage(), 0, 500);
            Log::error("Renvoi au syndic : " . $th->getMessage());
        }
        $nouveau = DB::table("syndic_envois")->insertGetId([
            "syndic_id" => $l->syndic_id, "booking_id" => $l->booking_id, "telephone" => $l->telephone, "statut" => $statut,
            "erreur" => $erreur, "message" => $message, "source" => "renvoi", "envoye_par" => $request->user()?->id,
            "created_at" => now(), "updated_at" => now(),
        ]);
        if ($statut !== "envoye") {
            return $this->jsonResponse(false, "L'envoi WhatsApp a échoué. Réessayez plus tard.", 502, null);
        }
        return $this->show($request, $nouveau);
    }
}
