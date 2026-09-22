<?php

namespace App\Http\Controllers\dashboard;

use App\Exports\StatistiquesExport;
use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\Charge;
use App\Models\Realstate;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Maatwebsite\Excel\Facades\Excel;
use Mpdf\Mpdf;

class StatistiquesExportController extends Controller
{
    /**
     * Export des statistiques au format xlsx ou pdf.
     * GET /api/dashboard/statistiques/export?format=xlsx|pdf&from=&to=&realestate=
     */
    public function export(Request $request)
    {
        $format = strtolower((string) $request->input('format', 'xlsx'));
        $from   = $request->filled('from') ? Carbon::parse($request->input('from'))->startOfDay()
                                           : now()->startOfMonth();
        $to     = $request->filled('to')   ? Carbon::parse($request->input('to'))->endOfDay()
                                           : now()->endOfDay();
        $bienId = $request->input('realestate');

        $entetes = ['Bien', 'Adresse', 'Réservations', 'Nuitées', 'Revenus (MAD)', 'Charges (MAD)', 'Solde (MAD)'];
        $lignes  = [];

        $biens = Realstate::with('city')
            ->when($bienId, fn($q) => $q->where('id', $bienId))
            ->get();

        foreach ($biens as $bien) {
            $reservations = Booking::where('realestate_id', $bien->id)
                ->whereBetween('created_at', [$from, $to])
                ->get();

            $charges = Charge::where('realestate_id', $bien->id)
                ->whereBetween('created_at', [$from, $to])
                ->sum('amount');

            $revenus = $reservations->sum('amount');
            $nuitees = $reservations->sum('nb_days');

            $lignes[] = [
                $bien->title ?? "Bien #{$bien->id}",
                $bien->address ?? '-',
                $reservations->count(),
                $nuitees,
                number_format((float) $revenus, 2, ',', ' '),
                number_format((float) $charges, 2, ',', ' '),
                number_format((float) $revenus - (float) $charges, 2, ',', ' '),
            ];
        }

        $periode = $from->format('d/m/Y') . ' au ' . $to->format('d/m/Y');
        $nom     = 'statistiques_' . now()->format('Ymd_His');

        if ($format === 'pdf') {
            $html = view('pdf.statistiques', [
                'titre'   => 'Statistiques par bien',
                'periode' => $periode,
                'entetes' => $entetes,
                'lignes'  => $lignes,
            ])->render();

            $mpdf = new Mpdf([
                // Les polices du projet, Amiri compris.
                ...config("pdf.polices"),
                'mode' => 'utf-8',
                'format' => 'A4-L',
                'margin_left' => 10,
                'margin_right' => 10,
                'margin_top' => 12,
                'margin_bottom' => 12,
            ]);
            $mpdf->WriteHTML($html);

            return response($mpdf->Output('', 'S'), 200, [
                'Content-Type'        => 'application/pdf',
                'Content-Disposition' => 'attachment; filename="' . $nom . '.pdf"',
            ]);
        }

        if ($format === 'csv') {
            // BOM UTF-8 pour qu'Excel ouvre correctement les accents,
            // point-virgule comme separateur (convention francaise).
            $csv = "ï»¿";
            $csv .= implode(';', $entetes) . "
";
            foreach ($lignes as $ligne) {
                $cellules = array_map(function ($c) {
                    $c = (string) $c;
                    return str_contains($c, ';') || str_contains($c, '"')
                        ? '"' . str_replace('"', '""', $c) . '"'
                        : $c;
                }, $ligne);
                $csv .= implode(';', $cellules) . "
";
            }

            return response($csv, 200, [
                'Content-Type'        => 'text/csv; charset=UTF-8',
                'Content-Disposition' => 'attachment; filename="' . $nom . '.csv"',
            ]);
        }

        return Excel::download(
            new StatistiquesExport($lignes, $entetes, 'Statistiques'),
            $nom . '.xlsx'
        );
    }
}
