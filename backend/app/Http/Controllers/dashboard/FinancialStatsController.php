<?php

namespace App\Http\Controllers\dashboard;

use App\Exports\ComparativeExport;
use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\FinancialTransaction;
use App\Models\Realstate;
use App\Models\User;
use App\utils\JsonResponses;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Maatwebsite\Excel\Facades\Excel;

class FinancialStatsController extends Controller
{
    use JsonResponses;

    public function index(Request $request)
    {
        $from    = Carbon::parse($request->input('from'))->startOfDay();
        $to      = Carbon::parse($request->input('to'))->endOfDay();
        $groupBy = $request->input('groupBy', 'month');
        $ids     = $request->input('realestate', []);

        // L'argent compte a sa date d'encaissement (par defaut), ou reparti
        // a parts egales sur les nuits du sejour.
        $parNuit = $request->input('repartition') === 'nuit';

        $tranches = $this->tranches($from, $to, $ids, $parNuit);

        $summary         = $this->buildSummary($tranches);
        // La part des reservations Airbnb, comprise dans les revenus.
        $summary['totalAirbnb'] = round((float) \Illuminate\Support\Facades\DB::table('financial_transactions')
            ->join('bookings', 'bookings.id', '=', 'financial_transactions.booking_id')
            ->whereNotNull('bookings.airbnb_uid')->where('financial_transactions.type', 'income')
            ->whereBetween('financial_transactions.transaction_date', [$from->toDateString(), $to->toDateString()])
            ->when(!empty($ids), fn($q) => $q->whereIn('bookings.realestate_id', (array) $ids))
            ->sum('financial_transactions.amount'), 2);
        // La T.V.A comprise dans les reservations facturees a la creation.
        $summary['totalTva'] = round(($summary['totalTva'] ?? 0) + (float) \Illuminate\Support\Facades\DB::table('factures')
            ->join('bookings', 'bookings.id', '=', 'factures.booking_id')
            ->where('factures.tva_incluse', true)->whereNull('bookings.deleted_at')
            ->whereBetween('factures.appliquee_le', [$from, $to])
            ->when(!empty($ids), fn($q) => $q->whereIn('bookings.realestate_id', (array) $ids))
            ->sum('factures.montant_tva'), 2);
        $revenueByPeriod = $this->buildRevenueByPeriod($tranches, $groupBy);
        $transactions    = $this->buildTransactions($tranches);
        $occupancy       = $this->buildOccupancy($from, $to, $ids);
        $clients         = $this->buildClients($from, $to, $ids);
        $comparative     = $this->buildComparative($from, $to, $ids, $tranches);
        $alerts          = $this->buildAlerts($summary, $occupancy, $comparative);

        return $this->successResponse([
            'repartition'     => $parNuit ? 'nuit' : 'encaissement',
            'summary'         => $summary,
            'revenueByPeriod' => $revenueByPeriod,
            'transactions'    => $transactions,
            'occupancy'       => $occupancy,
            'clients'         => $clients,
            'comparative'     => $comparative,
            'alerts'          => $alerts,
            // Toutes les operations passees dans les caisses sur la periode.
            'caisse'          => $this->buildCaisse($from, $to, (array) $ids),
        ]);
    }

    public function export(Request $request)
    {
        $from    = Carbon::parse($request->input('from'))->startOfDay();
        $to      = Carbon::parse($request->input('to'))->endOfDay();
        $ids     = $request->input('realestate', []);
        $parNuit = $request->input('repartition') === 'nuit';

        // buildComparative() indexe ses resultats par identifiant de bien.
        // On resout d'abord la selection - vide, elle vaut tous les biens -
        // puis on ne transmet que les identifiants.
        $identifiants = $this->resolveProperties($ids)->pluck('id')->all();
        $tranches     = $this->tranches($from, $to, $ids, $parNuit);
        $comparative  = $this->buildComparative($from, $to, $identifiants, $tranches);

        $filename = 'comparatif_' . now()->format('Ymd_His') . '.xlsx';
        return Excel::download(new ComparativeExport($comparative), $filename);
    }

    /**
     * Rapport de la periode, en PDF ou en Excel.
     *
     * Toujours : le resume, l'evolution mois par mois et les chiffres de
     * chaque appartement sur toute la periode. Avec le detail, chaque mois
     * a en plus les chiffres de chaque appartement et ses ecritures.
     */
    public function rapport(Request $request)
    {
        $validation = \Illuminate\Support\Facades\Validator::make($request->all(), [
            'from'   => ['required', 'date_format:Y-m-d'],
            'to'     => ['required', 'date_format:Y-m-d', 'after_or_equal:from'],
            'format' => ['nullable', 'in:pdf,xlsx'],
        ], [
            'from.required'      => 'Indiquez le début de la période.',
            'to.required'        => 'Indiquez la fin de la période.',
            'to.after_or_equal'  => 'La fin de la période doit suivre son début.',
        ]);
        if ($validation->fails()) {
            return $this->validationErrorResponse($validation->errors());
        }

        $from    = Carbon::parse($request->input('from'))->startOfDay();
        $to      = Carbon::parse($request->input('to'))->endOfDay();
        $ids     = array_values(array_filter((array) $request->input('realestate', [])));
        $parNuit = $request->input('repartition') === 'nuit';
        $detail  = $request->boolean('detail');
        $format  = $request->input('format', 'pdf');

        if ($from->copy()->addYears(5)->lt($to)) {
            return $this->validationErrorResponse(['msg' => ['La période ne peut pas dépasser 5 ans.']]);
        }

        $biens  = empty($ids) ? static::biensDeLAgence() : $ids;
        $titres = Realstate::whereIn('id', $biens)->pluck('title', 'id');

        $resumer = function (array $tranches, array $comparatif, Carbon $du, Carbon $au) {
            $s = $this->buildSummary($tranches);
            $nuits = (int) round($du->copy()->startOfDay()->diffInDays($au->copy()->startOfDay()->addDay()));
            $reservees = array_sum(array_column($comparatif, 'reservedDays'));
            $possibles = $nuits * max(count($comparatif), 1);
            return $s + [
                'nuitsReservees' => $reservees,
                'occupation'     => $possibles > 0 ? round($reservees / $possibles * 100, 1) : 0,
            ];
        };

        $tranches    = $this->tranches($from, $to, $ids, $parNuit);
        $comparatif  = $this->buildComparative($from, $to, $biens, $tranches);
        $resume      = $resumer($tranches, $comparatif, $from, $to);

        $mois = [];
        for ($debut = $from->copy()->startOfDay(); $debut->lte($to); $debut = $debut->copy()->addMonthNoOverflow()->startOfMonth()) {
            $fin = $debut->copy()->endOfMonth()->min($to);
            $t = $this->tranches($debut, $fin->copy()->endOfDay(), $ids, $parNuit);
            $c = $this->buildComparative($debut, $fin, $biens, $t);

            $ecritures = [];
            if ($detail) {
                foreach ($t as $x) {
                    $cle = $x['id'];
                    if (!isset($ecritures[$cle])) {
                        $ecritures[$cle] = $x + ['total' => 0.0];
                    }
                    $ecritures[$cle]['total'] += $x['amount'];
                    if ($x['date'] < $ecritures[$cle]['date']) {
                        $ecritures[$cle]['date'] = $x['date'];
                    }
                }
                usort($ecritures, fn($a, $b) => [$a['date'], $a['id']] <=> [$b['date'], $b['id']]);
            }

            $mois[] = [
                'libelle'   => ucfirst($debut->copy()->locale('fr')->isoFormat('MMMM YYYY')),
                'court'     => $debut->format('Y-m'),
                'du'        => $debut->copy(),
                'au'        => $fin->copy(),
                'resume'    => $resumer($t, $c, $debut, $fin),
                'biens'     => array_values(array_filter($c, fn($b) => $b['reservedDays'] > 0
                    || abs($b['revenue']) + abs($b['expenses']) + abs($b['refunds']) + abs($b['cancellations']) > 0)),
                'ecritures' => $ecritures,
            ];
        }

        $donnees = [
            'du'          => $from,
            'au'          => $to,
            'repartition' => $parNuit ? "argent réparti par nuit" : "argent à l'encaissement",
            'perimetre'   => empty($ids) ? 'Tous les appartements' : (count($biens) . ' appartement' . (count($biens) > 1 ? 's' : '') . ' choisi' . (count($biens) > 1 ? 's' : '')),
            'detail'      => $detail,
            'resume'      => $resume,
            'comparatif'  => $comparatif,
            'mois'        => $mois,
            'titres'      => $titres,
        ];

        $nom = 'rapport_' . $from->format('Ymd') . '_' . $to->format('Ymd') . ($detail ? '_detail' : '');
        if ($format === 'xlsx') {
            $chemin = \App\Services\RapportFinancier::excel($donnees);
            return response()->download($chemin, $nom . '.xlsx', [
                'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ])->deleteFileAfterSend(true);
        }

        return response(\App\Services\RapportFinancier::pdf($donnees), 200, [
            'Content-Type'        => 'application/pdf',
            'Content-Disposition' => 'attachment; filename="' . $nom . '.pdf"',
        ]);
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    /**
     * Les operations de caisse de la periode : encaissements, apports,
     * depenses, transferts, vidages... avec leur commentaire.
     * Filtre par bien : seules les operations liees a une reservation
     * ou une charge de ces biens.
     */
    private function buildCaisse(Carbon $from, Carbon $to, array $ids): array
    {
        $q = DB::table('mouvements_caisse as m')
            ->join('caisses as c', 'c.id', '=', 'm.caisse_id')
            ->leftJoin('managers as g', 'g.id', '=', 'm.manager_id')
            ->leftJoin('bookings as b', 'b.id', '=', 'm.booking_id')
            ->leftJoin('charges as ch', 'ch.id', '=', 'm.charge_id')
            ->whereBetween('m.effectue_le', [$from, $to]);
        if (!empty($ids)) {
            $q->where(fn($w) => $w->whereIn('b.realestate_id', $ids)->orWhereIn('ch.realestate_id', $ids));
        }
        $lignes = $q->orderByDesc('m.effectue_le')->orderByDesc('m.id')
            ->get(['m.id', 'm.sens', 'm.montant', 'm.motif', 'm.libelle', 'm.commentaire', 'm.booking_id',
                   'm.effectue_le', 'c.nom as caisse', 'c.type as caisseType', 'g.first_name', 'g.last_name']);

        $libelles = \App\Models\MouvementCaisse::LIBELLES;
        $entrees = 0.0; $sorties = 0.0; $parMotif = [];
        foreach ($lignes as $l) {
            // Le report d ouverture n est pas une operation : il reprend le solde precedent.
            if ($l->motif === \App\Models\MouvementCaisse::OUVERTURE) continue;
            $montant = (float) $l->montant;
            if ($l->sens === 'entree') $entrees += $montant; else $sorties += $montant;
            $cle = $l->motif . '|' . $l->sens;
            $parMotif[$cle] ??= ['motif' => $l->motif, 'libelle' => $libelles[$l->motif] ?? $l->motif,
                                 'sens' => $l->sens, 'nombre' => 0, 'total' => 0.0];
            $parMotif[$cle]['nombre']++;
            $parMotif[$cle]['total'] = round($parMotif[$cle]['total'] + $montant, 2);
        }
        usort($parMotif, fn($a, $b) => $b['total'] <=> $a['total']);

        return [
            'entrees'   => round($entrees, 2),
            'sorties'   => round($sorties, 2),
            'net'       => round($entrees - $sorties, 2),
            'parMotif'  => array_values($parMotif),
            'mouvements' => $lignes->take(500)->map(fn($l) => [
                'id'          => $l->id,
                'date'        => Carbon::parse($l->effectue_le)->toISOString(),
                'caisse'      => $l->caisse,
                'caisseType'  => $l->caisseType,
                'sens'        => $l->sens,
                'montant'     => (float) $l->montant,
                'motif'       => $l->motif,
                'libelle'     => $l->libelle ?: ($libelles[$l->motif] ?? $l->motif),
                'commentaire' => $l->commentaire,
                'bookingId'   => $l->booking_id,
                'par'         => trim(($l->first_name ?? '') . ' ' . ($l->last_name ?? '')) ?: null,
            ])->values()->all(),
        ];
    }

    private function resolveProperties(array $ids)
    {
        $query = Realstate::query();
        if (!empty($ids)) {
            $query->whereIn('id', $ids);
        }
        return $query->get(['id', 'title']);
    }

    /**
     * Les montants de la periode, en tranches datees.
     *
     * A l'encaissement, chaque ecriture est une tranche, a sa date
     * d'enregistrement.
     *
     * Reparti par nuit, tout l'argent d'une reservation - paiement,
     * prolongation, remboursement, annulation - est etale a parts egales
     * sur les nuits du sejour tel qu'il est aujourd'hui ; seules les nuits
     * de la periode comptent. Les charges n'ont pas de nuits : elles
     * restent a leur date, comme une ecriture dont le sejour est inconnu.
     */
    private function tranches(Carbon $from, Carbon $to, array $ids, bool $parNuit): array
    {
        $debut      = $from->toDateString();
        $fin        = $to->toDateString();
        $finPeriode = $to->copy()->startOfDay()->addDay()->toDateString();

        $avec = [
            // Une reservation ou une charge supprimee garde ses dates et son auteur.
            "booking" => fn($q) => $q->withTrashed(),
            "booking.manager",
            "booking.supprimeePar",
            "charge"  => fn($q) => $q->withTrashed(),
            "charge.manager",
        ];

        $tranches = [];
        $ajouter = function ($t, string $date, float $montant, ?string $detail = null) use (&$tranches) {
            $tranches[] = [
                'id'            => $t->id,
                'date'          => $date,
                'type'          => $t->type,
                'amount'        => $montant,
                'realestate_id' => $t->realestate_id,
                'description'   => $t->description,
                'detail'        => $detail,
                'par'           => static::auteurTransaction($t),
            ];
        };

        $parDate = FinancialTransaction::with($avec)->whereBetween('transaction_date', [$debut, $fin])
            // Un bien supprime, ou qui n'est pas celui de l'agence, ne compte pas.
            ->where(fn($q) => $q->whereNull('realestate_id')
                ->orWhereHas('realestate', fn($r) => $r->whereHas('host', fn($h) => $h->where('agence', 1))));
        if (!empty($ids)) {
            $parDate->whereIn('realestate_id', $ids);
        }

        foreach ($parDate->get() as $t) {
            // Par nuit, l'argent d'un sejour se compte sur ses nuits (plus bas).
            if ($parNuit && static::nuitsDuSejour($t->booking) > 0) {
                continue;
            }
            $ajouter($t, $t->transaction_date->toDateString(), (float) $t->amount);
        }

        if (!$parNuit) {
            return $tranches;
        }

        // L'argent des sejours qui touchent la periode, quelle que soit la
        // date a laquelle il a ete enregistre.
        $sejours = FinancialTransaction::with($avec)
            ->whereNotNull('booking_id')
            // Un bien supprime, ou qui n'est pas celui de l'agence, ne compte pas.
            ->where(fn($q) => $q->whereNull('realestate_id')
                ->orWhereHas('realestate', fn($r) => $r->whereHas('host', fn($h) => $h->where('agence', 1))))
            ->whereHas('booking', fn($q) => $q->withTrashed()
                ->where('checkin', '<', $finPeriode)
                ->where('checkout', '>', $debut));
        if (!empty($ids)) {
            $sejours->whereIn('realestate_id', $ids);
        }

        foreach ($sejours->get() as $t) {
            $nuits = static::nuitsDuSejour($t->booking);
            if ($nuits === 0) {
                continue;
            }

            $arrivee = Carbon::parse($t->booking->checkin)->toDateString();
            $depart  = Carbon::parse($t->booking->checkout)->toDateString();
            $premier = Carbon::parse(max($debut, $arrivee));
            $limite  = Carbon::parse(min($finPeriode, $depart));
            $dans    = (int) round($premier->diffInDays($limite));
            if ($dans <= 0) {
                continue;
            }

            $montantNuit = (float) $t->amount / $nuits;
            for ($i = 0; $i < $dans; $i++) {
                $ajouter($t, $premier->copy()->addDays($i)->toDateString(), $montantNuit, "$dans/$nuits nuits");
            }
        }

        return $tranches;
    }

    /**
     * Les biens pris en compte : ceux de l'agence, comme dans les listes de
     * l'application. Un bien supprime, ou rattache a un autre compte,
     * n'apparait ni dans l'occupation ni dans le comparatif.
     */
    /**
     * Les nuits d'un bien sur la periode : un bien desactive ne compte plus a
     * partir du jour de sa desactivation.
     */
    private static function joursActifs(int $bien, string $du, string $finPeriode, int $total): int
    {
        $le = Realstate::whereKey($bien)->value('desactive_le');
        if (!$le) {
            return $total;
        }
        $fin = min($finPeriode, Carbon::parse($le)->toDateString());
        return $fin > $du ? min($total, (int) round(Carbon::parse($du)->diffInDays(Carbon::parse($fin)))) : 0;
    }

    private static function biensDeLAgence(): array
    {
        // Un bien desactive avant le debut de la periode n'y figure plus.
        $debut = request()->filled('from') ? Carbon::parse(request()->input('from'))->startOfDay() : now()->startOfDay();
        return Realstate::whereHas('host', fn($q) => $q->where('agence', 1))
            ->where(fn($q) => $q->whereNull('desactive_le')->orWhere('desactive_le', '>', $debut))
            ->orderBy('id')
            ->pluck('id')
            ->toArray();
    }

    /** Le nombre de nuits d'un sejour ; 0 s'il est inconnu ou vide. */
    private static function nuitsDuSejour($booking): int
    {
        if ($booking === null || empty($booking->checkin) || empty($booking->checkout)) {
            return 0;
        }

        $nuits = (int) round(Carbon::parse($booking->checkin)->startOfDay()
            ->diffInDays(Carbon::parse($booking->checkout)->startOfDay(), false));

        return max($nuits, 0);
    }

    private function buildSummary(array $tranches): array
    {
        $totaux = ['income' => 0.0, 'expense' => 0.0, 'expense_reversal' => 0.0, 'refund' => 0.0, 'cancellation' => 0.0];
        foreach ($tranches as $x) {
            if (isset($totaux[$x['type']])) {
                $totaux[$x['type']] += $x['amount'];
            }
        }

        $income           = round($totaux['income'], 2);
        $expenses         = round($totaux['expense'], 2);
        $expenseReversals = round($totaux['expense_reversal'], 2);
        $refunds          = round($totaux['refund'], 2);
        $cancellations    = round($totaux['cancellation'], 2);

        $netExpenses = round($expenses - $expenseReversals, 2);

        return [
            'totalIncome'           => $income,
            'totalExpenses'         => $netExpenses,
            'totalExpenseReversals' => $expenseReversals,
            'totalRefunds'          => $refunds,
            'totalCancellations'    => $cancellations,
            'netProfit'             => round($income - $netExpenses - $refunds - $cancellations, 2),
            // La T.V.A des factures appliquees, comprise dans les revenus.
            'totalTva'              => round(array_sum(array_map(fn($x) => $x['type'] === 'income' && str_starts_with((string) ($x['description'] ?? ''), 'TVA - ') ? $x['amount'] : 0, $tranches)), 2),
        ];
    }

    private function buildRevenueByPeriod(array $tranches, string $groupBy): array
    {
        $longueur = match ($groupBy) {
            'day'   => 10,
            'year'  => 4,
            default => 7,
        };

        $grouped = [];
        foreach ($tranches as $x) {
            $p = substr($x['date'], 0, $longueur);
            if (!isset($grouped[$p])) {
                $grouped[$p] = ['period' => $p, 'income' => 0.0, 'expenses' => 0.0, 'refunds' => 0.0];
            }
            if ($x['type'] === 'income')           $grouped[$p]['income']   += $x['amount'];
            if ($x['type'] === 'expense')          $grouped[$p]['expenses'] += $x['amount'];
            if ($x['type'] === 'expense_reversal') $grouped[$p]['expenses'] -= $x['amount'];
            if ($x['type'] === 'refund')           $grouped[$p]['refunds']  += $x['amount'];
            // Une reservation supprimee vient en moins sur sa periode.
            if ($x['type'] === 'cancellation')     $grouped[$p]['income']   -= $x['amount'];
        }

        ksort($grouped);

        return array_values(array_map(fn($g) => [
            'period'   => $g['period'],
            'income'   => round($g['income'], 2),
            'expenses' => round($g['expenses'], 2),
            'refunds'  => round($g['refunds'], 2),
        ], $grouped));
    }

    /**
     * Une ligne par ecriture. Repartie par nuit, elle porte la part des
     * nuits de la periode et la date de la premiere de ces nuits.
     */
    private function buildTransactions(array $tranches): array
    {
        $lignes = [];
        foreach ($tranches as $x) {
            $cle = $x['id'];
            if (!isset($lignes[$cle])) {
                $lignes[$cle] = [
                    'id'          => $x['id'],
                    'date'        => $x['date'],
                    'type'        => $x['type'],
                    'amount'      => 0.0,
                    'description' => $x['description'] . ($x['detail'] ? ' (' . $x['detail'] . ')' : ''),
                    'par'         => $x['par'],
                ];
            }
            $lignes[$cle]['amount'] += $x['amount'];
            if ($x['date'] < $lignes[$cle]['date']) {
                $lignes[$cle]['date'] = $x['date'];
            }
        }

        usort($lignes, fn($a, $b) => [$b['date'], $b['id']] <=> [$a['date'], $a['id']]);

        return array_map(fn($l) => [
            'date'        => $l['date'],
            'type'        => $l['type'],
            'amount'      => round($l['amount'], 2),
            'description' => $l['description'],
            'par'         => $l['par'],
        ], $lignes);
    }

    /**
     * Qui est a l'origine de l'ecriture.
     *
     * Vide lorsqu'elle vient d'un traitement automatique : mieux vaut
     * rien qu'un nom arbitraire.
     */
    private static function auteurTransaction($transaction): ?string
    {
        // L'agent qui a fait l'operation, quand il est connu (prolongation, modification...).
        if (!empty($transaction->manager_id)) {
            $agent = \App\Models\Manager::withTrashed()->find($transaction->manager_id);
            if ($agent) {
                return trim(($agent->first_name ?? "") . " " . ($agent->last_name ?? "")) ?: null;
            }
        }

        // Une annulation porte le nom de celui qui a supprime la reservation.
        if ($transaction->type === 'cancellation' && $transaction->booking?->supprimeePar) {
            $auteur = $transaction->booking->supprimeePar;
            return trim(($auteur->first_name ?? "") . " " . ($auteur->last_name ?? "")) ?: null;
        }

        $manager = $transaction->charge?->manager ?? $transaction->booking?->manager;

        if ($manager === null) {
            return null;
        }

        return trim(($manager->first_name ?? "") . " " . ($manager->last_name ?? "")) ?: null;
    }

    private function buildOccupancy(Carbon $from, Carbon $to, $properties): array
    {
        $fromDate = $from->toDateString();
        $toDate   = $to->toDateString();
        // Nuits de la periode, dernier jour compris : du 01 au 13, 13 nuits.
        // diffInDays rend un decimal depuis Carbon 3 : on compte sur des
        // dates entieres.
        $finPeriode = $to->copy()->startOfDay()->addDay()->toDateString();
        $totalCalendarDays = (int) round(Carbon::parse($fromDate)->diffInDays(Carbon::parse($finPeriode)));

        $byProperty = [];
        $globalReservedDays = 0;
        $globalJours = 0;

        $properties = empty($properties) ? static::biensDeLAgence() : $properties;

        foreach ($properties as $prop) {
            $bookings = Booking::where('realestate_id', $prop)
                ->whereHas('status', fn($q) => $q->whereIn('code', ['payed', 'completed']))
                ->where('checkin', '<', $finPeriode)
                ->where('checkout', '>', $fromDate)
                ->get(['checkin', 'checkout']);

            $reservedDays = 0;
            foreach ($bookings as $b) {
                $start = max($fromDate, $b->checkin);
                $end   = min($finPeriode, $b->checkout);
                if ($end > $start) {
                    $reservedDays += (int) round(Carbon::parse($start)->diffInDays(Carbon::parse($end)));
                }
            }
            $joursBien = static::joursActifs((int) $prop, $fromDate, $finPeriode, $totalCalendarDays);
            $globalJours += $joursBien;
            $reservedDays = min($reservedDays, $joursBien);

            $globalReservedDays += $reservedDays;
            $rate = $joursBien > 0
                ? round($reservedDays / $joursBien * 100, 1)
                : 0;
            $property = Realstate::find($prop);

            $byProperty[] = [
                'id'             => $property->id,
                'title'          => $property->title,
                'totalDays'      => $joursBien,
                'reservedDays'   => $reservedDays,
                'nonReservedDays' => $joursBien - $reservedDays,
                'rate'           => $rate,
            ];
        }

        $propCount = count($byProperty);
        $globalTotal = $propCount > 0 ? $globalJours : $totalCalendarDays;
        $globalRate  = $globalTotal > 0
            ? round($globalReservedDays / $globalTotal * 100, 1)
            : 0;

        return [
            'totalDays'      => $globalTotal,
            'reservedDays'   => $globalReservedDays,
            'nonReservedDays' => $globalTotal - $globalReservedDays,
            'rate'           => $globalRate,
            'byProperty'     => $byProperty,
        ];
    }

    private function buildClients(Carbon $from, Carbon $to, array $ids): array
    {
        $total = User::whereHas('type', fn($q) => $q->where('code', 'client'))->count();

        $bookingBase = Booking::whereHas('status', fn($q) => $q->whereIn('code', ['payed', 'completed']));
        if (!empty($ids)) {
            $bookingBase->whereIn('realestate_id', $ids);
        }

        $newClients = (clone $bookingBase)
            ->whereBetween('created_at', [$from, $to])
            ->distinct()
            ->pluck('client_id');

        $firstBookings = Booking::select('client_id', DB::raw('MIN(created_at) as first_at'))
            ->groupBy('client_id')
            ->havingRaw('MIN(created_at) >= ?', [$from])
            ->havingRaw('MIN(created_at) <= ?', [$to])
            ->pluck('client_id');

        $newCount = $newClients->intersect($firstBookings)->count();

        $returningCount = (clone $bookingBase)
            ->whereBetween('created_at', [$from, $to])
            ->select('client_id', DB::raw('COUNT(*) as cnt'))
            ->groupBy('client_id')
            ->havingRaw('COUNT(*) >= 2')
            ->count();

        return [
            'total'     => $total,
            'new'       => $newCount,
            'returning' => $returningCount,
        ];
    }

    private function buildComparative(Carbon $from, Carbon $to, $properties, array $tranches): array
    {
        $fromDate = $from->toDateString();

        // Les montants de chaque bien, selon la meme repartition que le reste.
        $base = [];
        foreach ($tranches as $x) {
            $bien = $x['realestate_id'];
            $base[$bien][$x['type']] = ($base[$bien][$x['type']] ?? 0) + $x['amount'];
        }

        // Nuits de la periode, dernier jour compris : du 01 au 13, 13 nuits.
        // diffInDays rend un decimal depuis Carbon 3 : on compte sur des
        // dates entieres.
        $finPeriode = $to->copy()->startOfDay()->addDay()->toDateString();
        $totalCalendarDays = (int) round(Carbon::parse($fromDate)->diffInDays(Carbon::parse($finPeriode)));

        $properties = empty($properties) ? static::biensDeLAgence() : $properties;
        $result = [];
        foreach ($properties as $prop) {
            $bookings = Booking::where('realestate_id', $prop)
                ->whereHas('status', fn($q) => $q->whereIn('code', ['payed', 'completed']))
                ->where('checkin', '<', $finPeriode)
                ->where('checkout', '>', $fromDate)
                ->get(['checkin', 'checkout']);

            $reservedDays = 0;
            foreach ($bookings as $b) {
                $start = max($fromDate, $b->checkin);
                $end   = min($finPeriode, $b->checkout);
                if ($end > $start) {
                    $reservedDays += (int) round(Carbon::parse($start)->diffInDays(Carbon::parse($end)));
                }
            }
            $joursBien = static::joursActifs((int) $prop, $fromDate, $finPeriode, $totalCalendarDays);
            $reservedDays = min($reservedDays, $joursBien);

            $propRows      = $base[$prop] ?? [];
            $rev           = round((float) ($propRows['income']           ?? 0), 2);
            $exp           = round((float) ($propRows['expense']          ?? 0), 2);
            $expRev        = round((float) ($propRows['expense_reversal'] ?? 0), 2);
            $refunds       = round((float) ($propRows['refund']           ?? 0), 2);
            $cancellations = round((float) ($propRows['cancellation']     ?? 0), 2);
            $netExp        = round($exp - $expRev, 2);

            $property = Realstate::find($prop);
            $result[] = [
                'id'             => $property->id,
                'title'          => $property->title,
                'reservedDays'   => $reservedDays,
                'nonReservedDays' => $joursBien - $reservedDays,
                'revenue'        => $rev,
                'expenses'       => $netExp,
                'refunds'        => $refunds,
                'cancellations'  => $cancellations,
                'profit'         => round($rev - $netExp - $refunds - $cancellations, 2),
            ];
        }

        return $result;
    }

    private function buildAlerts(array $summary, array $occupancy, array $comparative): array
    {
        $alerts = [];

        foreach ($occupancy['byProperty'] as $prop) {
            if ($prop['rate'] < 30) {
                $priority = $prop['rate'] < 10 ? 'high' : 'medium';
                $color    = $prop['rate'] < 10 ? 'red' : 'orange';
                $alerts[] = [
                    'type'     => 'low_occupancy',
                    'priority' => $priority,
                    'color'    => $color,
                    'message'  => "{$prop['title']}: taux d'occupation {$prop['rate']}% < seuil 30%",
                    'detail'   => $prop,
                ];
            }
        }

        foreach ($comparative as $prop) {
            if ($prop['revenue'] > 0 && $prop['expenses'] / $prop['revenue'] > 0.5) {
                $alerts[] = [
                    'type'     => 'high_expenses',
                    'priority' => 'high',
                    'color'    => 'red',
                    'message'  => "{$prop['title']}: dépenses représentent " . round($prop['expenses'] / $prop['revenue'] * 100) . "% du CA",
                    'detail'   => $prop,
                ];
            }

            if ($prop['profit'] < 0) {
                $alerts[] = [
                    'type'     => 'negative_profit',
                    'priority' => 'high',
                    'color'    => 'red',
                    'message'  => "{$prop['title']}: bénéfice négatif " . number_format($prop['profit'], 2) . " MAD",
                    'detail'   => $prop,
                ];
            } elseif ($prop['profit'] < 2000 && $prop['profit'] >= 0) {
                $alerts[] = [
                    'type'     => 'low_profit',
                    'priority' => 'medium',
                    'color'    => 'orange',
                    'message'  => "{$prop['title']}: bénéfice faible " . number_format($prop['profit'], 2) . " MAD",
                    'detail'   => $prop,
                ];
            }
        }

        if ($summary['netProfit'] < 0) {
            $alerts[] = [
                'type'     => 'negative_global_profit',
                'priority' => 'high',
                'color'    => 'red',
                'message'  => 'Bénéfice global négatif: ' . number_format($summary['netProfit'], 2) . ' MAD',
                'detail'   => $summary,
            ];
        }

        return $alerts;
    }
}
