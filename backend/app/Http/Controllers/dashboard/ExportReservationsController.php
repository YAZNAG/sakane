<?php

namespace App\Http\Controllers\dashboard;

use App\Exports\ReservationsExport;
use App\Http\Controllers\Controller;
use App\Models\Realstate;
use App\Models\User;
use App\Services\ReservationsExportees;
use App\Services\TypesInvites;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Maatwebsite\Excel\Facades\Excel;
use Mpdf\Mpdf;

/**
 * Export des reservations, par bien ou par client.
 *
 * La selection est multiple des deux cotes. Sans selection, l'export
 * porte sur tout ce que l'agent a le droit de voir - ses dossiers.
 */
class ExportReservationsController extends Controller
{
    use JsonResponses;

    public function export(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "format"        => ["nullable", "in:xlsx,pdf"],
            "realestates"   => ["nullable", "array"],
            "realestates.*" => ["integer"],
            "clients"       => ["nullable", "array"],
            "clients.*"     => ["integer"],
            "du"            => ["nullable", "date"],
            "au"            => ["nullable", "date"],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $biens   = array_map("intval", (array) $request->input("realestates", []));
        $clients = array_map("intval", (array) $request->input("clients", []));
        $format  = $request->input("format", "xlsx");

        $autorises = $request->user()?->dossiersAutorises();

        $lignes = ReservationsExportees::lignes(
            $biens,
            $clients,
            $request->input("du"),
            $request->input("au"),
            $autorises
        );

        $intitule = $this->intitule($biens, $clients);
        $horodate = now()->format("Ymd_His");

        if ($format === "pdf") {
            return $this->pdf($lignes, $intitule, $horodate, $request);
        }

        return Excel::download(
            new ReservationsExport($lignes, "R\u{E9}servations"),
            "reservations_" . $horodate . ".xlsx"
        );
    }

    /** Les types d'invites, pour que les applications les affichent. */
    public function typesInvites()
    {
        return $this->successResponse(TypesInvites::liste());
    }

    /**
     * mPDF borne chaque appel a WriteHTML() par pcre.backtrack_limit.
     * On lui donne donc l'entete, puis les lignes par paquets, puis le
     * pied : chaque morceau reste bien en deca de la limite, quel que
     * soit le nombre de reservations.
     */
    private const LIGNES_PAR_PAQUET = 150;

    private function pdf(array $lignes, string $intitule, string $horodate, Request $request)
    {
        $mpdf = new Mpdf([
            // Les polices du projet, Amiri compris.
            ...config("pdf.polices"),
            "mode"             => "utf-8",
            "format"           => "A4-L",
            "autoScriptToLang" => true,
            "autoLangToFont"   => true,
            "tempDir"          => storage_path("app/mpdf"),
        ]);

        $mpdf->WriteHTML(view("pdf.reservations_entete", [
            "titre"     => "Liste des r\u{E9}servations",
            "sousTitre" => $intitule,
            "colonnes"  => ReservationsExportees::COLONNES,
            "nombre"    => count($lignes),
            "editeLe"   => now()->format("d/m/Y H:i"),
        ])->render());

        foreach (array_chunk($lignes, self::LIGNES_PAR_PAQUET) as $paquet) {
            $mpdf->WriteHTML(
                view("pdf.reservations_lignes", ["lignes" => $paquet])->render(),
                \Mpdf\HTMLParserMode::HTML_BODY
            );
        }

        $mpdf->WriteHTML(view("pdf.reservations_pied", [
            "totaux" => empty($lignes) ? [] : ReservationsExportees::totaux($lignes),
            "agence" => config("app.name"),
        ])->render(), \Mpdf\HTMLParserMode::HTML_BODY);

        return response($mpdf->Output("", "S"), 200, [
            "Content-Type"        => "application/pdf",
            "Content-Disposition" => 'attachment; filename="reservations_' . $horodate . '.pdf"',
        ]);
    }

    /** De quoi rappeler, en tete du fichier, ce qui a ete selectionne. */
    private function intitule(array $biens, array $clients): string
    {
        $parties = [];

        if (!empty($biens)) {
            $noms = Realstate::whereIn("id", $biens)->pluck("title")->filter()->all();
            $parties[] = count($noms) <= 3
                ? implode(", ", $noms)
                : count($noms) . " biens";
        }

        if (!empty($clients)) {
            $noms = User::whereIn("id", $clients)
                ->get()
                ->map(fn($c) => trim($c->first_name . " " . $c->last_name))
                ->filter()
                ->all();
            $parties[] = count($noms) <= 3
                ? implode(", ", $noms)
                : count($noms) . " clients";
        }

        return empty($parties) ? "Toutes les r\u{E9}servations" : implode(" \u{2014} ", $parties);
    }
}
