<?php

namespace App\Services;

use App\Models\User;
use Carbon\Carbon;
use Mpdf\Mpdf;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

/**
 * Mise en page du rapport financier : PDF pour l'impression, Excel pour
 * retravailler les chiffres. Les donnees viennent de
 * FinancialStatsController::rapport().
 */
class RapportFinancier
{
    private const TYPES = [
        'income'           => 'Revenu',
        'expense'          => 'Dépense',
        'expense_reversal' => 'Dépense annulée',
        'refund'           => 'Remboursement',
        'cancellation'     => 'Annulation',
    ];

    private const COLONNES_BIENS = ['Appartement', 'Nuits rés.', 'Occupation', 'Revenus', 'Dépenses', 'Remb.', 'Annul.', 'Bénéfice'];

    public static function entete(): array
    {
        $agence = User::where('agence', '1')->first();
        $nom = trim((string) config('agence.nom'));
        if ($nom === '') {
            $nom = trim(($agence->first_name ?? '') . ' ' . ($agence->last_name ?? ''));
        }
        if ($nom === '') {
            $nom = (string) config('app.name');
        }

        $logo = null;
        try {
            $media = $agence?->getFirstMedia('profile_photo');
            if ($media && is_readable($media->getPath())) {
                $logo = $media->getPath();
            }
        } catch (\Throwable $e) {
            $logo = null;
        }

        $couleur = str_contains(strtolower((string) config('app.name')), 'alwed') ? '0E7C86' : '1F5F8B';

        return ['nom' => $nom, 'logo' => $logo, 'couleur' => $couleur];
    }

    private static function montant(float $v): string
    {
        return number_format($v, 2, ',', ' ');
    }

    private static function date($d): string
    {
        return Carbon::parse($d)->format('d/m/Y');
    }

    private static function taux(int $reservees, int $nuits): float
    {
        return $nuits > 0 ? round($reservees / $nuits * 100, 1) : 0;
    }

    /**
     * Une ligne par appartement, et la ligne des totaux.
     *
     * Avec le resume, l'argent sans appartement (salaires, fournitures...)
     * a sa propre ligne : le total rejoint alors celui du resume.
     */
    private static function lignesBiens(array $biens, int $nuitsPeriode, ?array $resume = null): array
    {
        if ($resume !== null) {
            $ecart = [
                'revenue'       => $resume['totalIncome'] - array_sum(array_column($biens, 'revenue')),
                'expenses'      => $resume['totalExpenses'] - array_sum(array_column($biens, 'expenses')),
                'refunds'       => $resume['totalRefunds'] - array_sum(array_column($biens, 'refunds')),
                'cancellations' => $resume['totalCancellations'] - array_sum(array_column($biens, 'cancellations')),
                'profit'        => $resume['netProfit'] - array_sum(array_column($biens, 'profit')),
            ];
            $ecart = array_map(fn($v) => round($v, 2), $ecart);
            if (array_filter($ecart, fn($v) => abs($v) >= 0.01)) {
                [$lignes, $totaux] = static::lignesBiens($biens, $nuitsPeriode);
                $lignes[] = ['Charges générales (sans appartement)', null, null,
                    $ecart['revenue'], $ecart['expenses'], $ecart['refunds'], $ecart['cancellations'], $ecart['profit']];
                foreach ([3 => 'revenue', 4 => 'expenses', 5 => 'refunds', 6 => 'cancellations', 7 => 'profit'] as $k => $cle) {
                    $totaux[$k] = round($totaux[$k] + $ecart[$cle], 2);
                }
                return [$lignes, $totaux];
            }
        }

        $lignes = [];
        $t = ['n' => 0, 'r' => 0.0, 'd' => 0.0, 'rb' => 0.0, 'a' => 0.0, 'b' => 0.0];
        foreach ($biens as $b) {
            $lignes[] = [
                (string) $b['title'],
                $b['reservedDays'],
                static::taux($b['reservedDays'], $nuitsPeriode),
                $b['revenue'], $b['expenses'], $b['refunds'], $b['cancellations'], $b['profit'],
            ];
            $t['n'] += $b['reservedDays'];
            $t['r'] += $b['revenue'];
            $t['d'] += $b['expenses'];
            $t['rb'] += $b['refunds'];
            $t['a'] += $b['cancellations'];
            $t['b'] += $b['profit'];
        }
        $totaux = ['TOTAL', $t['n'], static::taux($t['n'], $nuitsPeriode * max(count($biens), 1)),
            round($t['r'], 2), round($t['d'], 2), round($t['rb'], 2), round($t['a'], 2), round($t['b'], 2)];
        return [$lignes, $totaux];
    }

    private static function nuits(Carbon $du, Carbon $au): int
    {
        return (int) round($du->copy()->startOfDay()->diffInDays($au->copy()->startOfDay()->addDay()));
    }

    private static function lignesMois(array $mois): array
    {
        $lignes = [];
        $t = ['r' => 0.0, 'd' => 0.0, 'rb' => 0.0, 'a' => 0.0, 'b' => 0.0, 'n' => 0];
        foreach ($mois as $m) {
            $r = $m['resume'];
            $lignes[] = [$m['libelle'], $r['totalIncome'], $r['totalExpenses'], $r['totalRefunds'],
                $r['totalCancellations'], $r['netProfit'], $r['nuitsReservees'], $r['occupation']];
            $t['r'] += $r['totalIncome'];
            $t['d'] += $r['totalExpenses'];
            $t['rb'] += $r['totalRefunds'];
            $t['a'] += $r['totalCancellations'];
            $t['b'] += $r['netProfit'];
            $t['n'] += $r['nuitsReservees'];
        }
        return [$lignes, ['TOTAL', round($t['r'], 2), round($t['d'], 2), round($t['rb'], 2), round($t['a'], 2), round($t['b'], 2), $t['n'], null]];
    }

    private static function lignesEcritures(array $ecritures, $titres): array
    {
        $lignes = [];
        $net = 0.0;
        foreach ($ecritures as $e) {
            $positif = in_array($e['type'], ['income', 'expense_reversal'], true);
            $valeur = round($positif ? $e['total'] : -$e['total'], 2);
            $net += $valeur;
            $lignes[] = [
                static::date($e['date']),
                (string) ($titres[$e['realestate_id']] ?? '—'),
                static::TYPES[$e['type']] ?? $e['type'],
                trim($e['description'] . ($e['detail'] ? ' (' . $e['detail'] . ')' : '')),
                (string) ($e['par'] ?? ''),
                $valeur,
            ];
        }
        return [$lignes, ['TOTAL', '', '', '', '', round($net, 2)]];
    }

    // ------------------------------------------------------------------
    // PDF
    // ------------------------------------------------------------------

    public static function pdf(array $d): string
    {
        ini_set('pcre.backtrack_limit', '50000000');
        $e = static::entete();
        $c = '#' . $e['couleur'];

        $options = [
            'mode' => 'utf-8', 'format' => 'A4', 'orientation' => 'L',
            'margin_left' => 10, 'margin_right' => 10, 'margin_top' => 10,
            'margin_bottom' => 16, 'margin_footer' => 6,
            'autoScriptToLang' => true, 'autoLangToFont' => true,
        ];
        $polices = config('pdf.polices');
        if (is_array($polices)) {
            $options = array_merge($polices, $options);
        }
        $mpdf = new Mpdf($options);

        $periode = 'Du ' . static::date($d['du']) . ' au ' . static::date($d['au']);
        $mpdf->SetHTMLFooter('<table width="100%" style="font-size:7.5pt;color:#6b7b84;border-top:0.4px solid #d5dde2;padding-top:3px;"><tr>'
            . '<td>' . e($e['nom']) . ' — Rapport financier — ' . e($periode) . '</td>'
            . '<td align="right">Page {PAGENO} / {nbpg}</td></tr></table>');

        $logo = '';
        if ($e['logo']) {
            $mime = mime_content_type($e['logo']) ?: 'image/png';
            $logo = '<td width="120"><img src="data:' . $mime . ';base64,' . base64_encode(file_get_contents($e['logo'])) . '" style="height:54px;max-width:110px;" /></td>';
        }

        $cell = function ($v, bool $pourcent = false) {
            if ($v === null || $v === '') return '<td class="vide-case">-</td>';
            if (is_int($v) && !$pourcent) return '<td class="n">' . $v . '</td>';
            if (is_int($v) || is_float($v)) {
                return '<td class="n' . ($v < 0 ? ' neg' : '') . '">' . ($pourcent ? number_format($v, 1, ',', ' ') . ' %' : static::montant($v)) . '</td>';
            }
            return '<td>' . e($v) . '</td>';
        };
        $tableau = function (array $colonnes, array $lignes, ?array $totaux, array $pourcent = [], string $vide = 'Aucune ligne.') use ($cell) {
            $h = '<table class="t" repeat_header="1"><thead><tr>'
                . implode('', array_map(fn($x) => '<th>' . e($x) . '</th>', $colonnes)) . '</tr></thead><tbody>';
            foreach ($lignes as $i => $l) {
                $h .= '<tr' . ($i % 2 ? ' class="p"' : '') . '>';
                foreach (array_values($l) as $k => $v) $h .= $cell($v, in_array($k, $pourcent, true));
                $h .= '</tr>';
            }
            if (empty($lignes)) {
                $h .= '<tr><td colspan="' . count($colonnes) . '" class="vide">' . e($vide) . '</td></tr>';
            } elseif ($totaux !== null) {
                $h .= '<tr class="tot">';
                foreach (array_values($totaux) as $k => $v) $h .= $cell($v, in_array($k, $pourcent, true));
                $h .= '</tr>';
            }
            return $h . '</tbody></table>';
        };

        $r = $d['resume'];
        $cartes = [
            ['Revenus', static::montant($r['totalIncome']) . ' MAD', ''],
            ['Dépenses', static::montant($r['totalExpenses']) . ' MAD', ''],
            ['Remboursements', static::montant($r['totalRefunds']) . ' MAD', ''],
            ['Annulations', static::montant($r['totalCancellations']) . ' MAD', ''],
            ['Bénéfice net', static::montant($r['netProfit']) . ' MAD', $r['netProfit'] < 0 ? 'neg' : 'pos'],
            ['Occupation', number_format($r['occupation'], 1, ',', ' ') . ' %', ''],
        ];
        $htmlCartes = '<table class="cartes"><tr>' . implode('', array_map(
            fn($k) => '<td><div class="lib">' . e($k[0]) . '</div><div class="val ' . $k[2] . '">' . e($k[1]) . '</div></td>', $cartes)) . '</tr></table>';

        $nuitsPeriode = static::nuits($d['du'], $d['au']);
        [$lb, $tb] = static::lignesBiens($d['comparatif'], $nuitsPeriode, $d['resume']);
        [$lm, $tm] = static::lignesMois($d['mois']);

        $html = '<style>
  body { font-family: sans-serif; color: #17262e; }
  table.bandeau { width: 100%; border-collapse: collapse; }
  .agence { font-size: 10pt; font-weight: bold; color: ' . $c . '; letter-spacing: 0.5px; }
  .titre { font-size: 18pt; font-weight: bold; margin-top: 2px; }
  .sous { font-size: 9.5pt; color: #4a5b64; margin-top: 3px; }
  .meta { font-size: 8pt; color: #6b7b84; text-align: right; line-height: 1.5; }
  .filet { height: 3px; background: ' . $c . '; margin: 6px 0 10px 0; }
  h2 { font-size: 12.5pt; color: ' . $c . '; margin: 14px 0 6px 0; }
  h3 { font-size: 10.5pt; color: #17262e; margin: 10px 0 5px 0; }
  table.cartes { width: 100%; border-collapse: separate; border-spacing: 5px; }
  table.cartes td { background: #f1f5f8; border: 0.4px solid #dbe3e8; padding: 7px 8px; width: 16%; }
  .lib { font-size: 7.5pt; color: #5d6d76; text-transform: uppercase; }
  .val { font-size: 12pt; font-weight: bold; margin-top: 2px; }
  .pos { color: #1c7c45; } .neg { color: #c0392b; }
  table.t { width: 100%; border-collapse: collapse; font-size: 8.3pt; margin-bottom: 6px; }
  table.t th { background: ' . $c . '; color: #fff; padding: 5px; border: 0.3px solid ' . $c . '; }
  table.t td { padding: 4px 5px; border-bottom: 0.3px solid #dfe6ea; vertical-align: top; }
  table.t td.n { text-align: right; white-space: nowrap; }
  table.t td.n.neg { color: #c0392b; }
  table.t td.vide-case { text-align: center; color: #98a6ae; }
  table.t tr.p td { background: #f4f7f9; }
  table.t tr.tot td { font-weight: bold; background: #e6eef4; border-top: 1.2px solid ' . $c . '; }
  td.vide { text-align: center; color: #6b7b84; padding: 10px; }
  .bloc-mois { font-size: 9pt; color: #4a5b64; margin-bottom: 4px; }
</style>
<table class="bandeau"><tr>' . $logo . '<td>
  <div class="agence">' . e(mb_strtoupper($e['nom'])) . '</div>
  <div class="titre">Rapport financier' . ($d['detail'] ? ' détaillé' : '') . '</div>
  <div class="sous">' . e($periode) . ' — ' . e($d['perimetre']) . ' — ' . e($d['repartition']) . '</div>
</td><td class="meta" width="160">Édité le ' . now()->format('d/m/Y') . '<br/>à ' . now()->format('H:i') . '</td></tr></table>
<div class="filet"></div>
<h2>Résumé de la période</h2>' . $htmlCartes . '
<h2>Évolution mois par mois</h2>'
            . $tableau(['Mois', 'Revenus', 'Dépenses', 'Remb.', 'Annul.', 'Bénéfice', 'Nuits rés.', 'Occupation'], $lm, $tm, [7])
            . '<h2>Par appartement — toute la période</h2>'
            . $tableau(static::COLONNES_BIENS, $lb, $tb, [2], 'Aucun appartement.');

        if ($d['detail']) {
            foreach ($d['mois'] as $m) {
                $rm = $m['resume'];
                [$lbm, $tbm] = static::lignesBiens($m['biens'], static::nuits($m['du'], $m['au']), $m['resume']);
                $html .= '<pagebreak />'
                    . '<h2>' . e($m['libelle']) . '</h2>'
                    . '<div class="bloc-mois">Du ' . static::date($m['du']) . ' au ' . static::date($m['au'])
                    . ' — Revenus ' . static::montant($rm['totalIncome']) . ' MAD · Dépenses ' . static::montant($rm['totalExpenses'])
                    . ' MAD · Bénéfice <b>' . static::montant($rm['netProfit']) . ' MAD</b> · Occupation '
                    . number_format($rm['occupation'], 1, ',', ' ') . ' %</div>'
                    . '<h3>Chiffres par appartement</h3>'
                    . $tableau(static::COLONNES_BIENS, $lbm, $tbm, [2], 'Aucune activité ce mois-ci.');
                [$le, $te] = static::lignesEcritures($m['ecritures'], $d['titres']);
                $html .= '<h3>Écritures du mois</h3>'
                    . $tableau(['Date', 'Appartement', 'Type', 'Description', 'Par', 'Montant'], $le, $te, [], 'Aucune écriture ce mois-ci.');
            }
        }

        set_error_handler(fn() => true, E_WARNING | E_NOTICE | E_DEPRECATED | E_USER_WARNING | E_USER_NOTICE);
        try {
            $mpdf->WriteHTML($html);
            return $mpdf->Output('', 'S');
        } finally {
            restore_error_handler();
        }
    }

    // ------------------------------------------------------------------
    // Excel
    // ------------------------------------------------------------------

    public static function excel(array $d): string
    {
        $e = static::entete();
        $classeur = new Spreadsheet();
        $feuille = $classeur->getActiveSheet();
        $feuille->setTitle('Récapitulatif');

        $periode = 'Du ' . static::date($d['du']) . ' au ' . static::date($d['au']);
        $ligne = 1;
        $feuille->setCellValue('A1', $e['nom'] . ' — Rapport financier' . ($d['detail'] ? ' détaillé' : ''));
        $feuille->getStyle('A1')->getFont()->setBold(true)->setSize(14);
        $feuille->setCellValue('A2', $periode . ' — ' . $d['perimetre'] . ' — ' . $d['repartition']);
        $feuille->setCellValue('A3', 'Édité le ' . now()->format('d/m/Y H:i'));
        $ligne = 5;

        $r = $d['resume'];
        $ligne = static::bloc($feuille, $ligne, 'Résumé de la période', ['Indicateur', 'Valeur'], [
            ['Revenus (MAD)', $r['totalIncome']],
            ['Dépenses (MAD)', $r['totalExpenses']],
            ['Remboursements (MAD)', $r['totalRefunds']],
            ['Annulations (MAD)', $r['totalCancellations']],
            ['Bénéfice net (MAD)', $r['netProfit']],
            ['Nuits réservées', $r['nuitsReservees']],
            ['Occupation (%)', $r['occupation']],
        ], null, $e['couleur']);

        [$lm, $tm] = static::lignesMois($d['mois']);
        $ligne = static::bloc($feuille, $ligne, 'Évolution mois par mois',
            ['Mois', 'Revenus', 'Dépenses', 'Remb.', 'Annul.', 'Bénéfice', 'Nuits rés.', 'Occupation (%)'], $lm, $tm, $e['couleur']);

        [$lb, $tb] = static::lignesBiens($d['comparatif'], static::nuits($d['du'], $d['au']), $d['resume']);
        static::bloc($feuille, $ligne, 'Par appartement — toute la période',
            ['Appartement', 'Nuits rés.', 'Occupation (%)', 'Revenus', 'Dépenses', 'Remb.', 'Annul.', 'Bénéfice'], $lb, $tb, $e['couleur']);
        static::largeurs($feuille, 8);

        if ($d['detail']) {
            foreach ($d['mois'] as $m) {
                $f = $classeur->createSheet();
                $f->setTitle($m['court']);
                $f->setCellValue('A1', $m['libelle']);
                $f->getStyle('A1')->getFont()->setBold(true)->setSize(13);
                $f->setCellValue('A2', 'Du ' . static::date($m['du']) . ' au ' . static::date($m['au']));
                [$lbm, $tbm] = static::lignesBiens($m['biens'], static::nuits($m['du'], $m['au']), $m['resume']);
                $l = static::bloc($f, 4, 'Chiffres par appartement',
                    ['Appartement', 'Nuits rés.', 'Occupation (%)', 'Revenus', 'Dépenses', 'Remb.', 'Annul.', 'Bénéfice'], $lbm, $tbm, $e['couleur']);
                [$le, $te] = static::lignesEcritures($m['ecritures'], $d['titres']);
                static::bloc($f, $l, 'Écritures du mois', ['Date', 'Appartement', 'Type', 'Description', 'Par', 'Montant'], $le, $te, $e['couleur']);
                static::largeurs($f, 8);
            }
        }

        $classeur->setActiveSheetIndex(0);
        $base = tempnam(sys_get_temp_dir(), 'rapport_');
        @unlink($base);
        $chemin = $base . '.xlsx';
        (new Xlsx($classeur))->save($chemin);
        return $chemin;
    }

    /** Ecrit un titre, un tableau et ses totaux ; renvoie la ligne suivante libre. */
    private static function bloc($feuille, int $ligne, string $titre, array $colonnes, array $lignes, ?array $totaux, string $couleur): int
    {
        $feuille->setCellValue('A' . $ligne, $titre);
        $feuille->getStyle('A' . $ligne)->getFont()->setBold(true)->setSize(12)->getColor()->setRGB($couleur);
        $ligne++;

        $feuille->fromArray($colonnes, null, 'A' . $ligne);
        $fin = chr(ord('A') + count($colonnes) - 1);
        $style = $feuille->getStyle("A{$ligne}:{$fin}{$ligne}");
        $style->getFont()->setBold(true)->getColor()->setRGB('FFFFFF');
        $style->getFill()->setFillType(Fill::FILL_SOLID)->getStartColor()->setRGB($couleur);
        $ligne++;

        if (empty($lignes)) {
            $feuille->setCellValue('A' . $ligne, 'Aucune ligne.');
            $feuille->getStyle('A' . $ligne)->getFont()->setItalic(true);
            return $ligne + 2;
        }
        $debut = $ligne;
        foreach ($lignes as $l) {
            $feuille->fromArray(array_values($l), null, 'A' . $ligne, true);
            $ligne++;
        }
        $feuille->getStyle("B{$debut}:{$fin}" . ($ligne))->getNumberFormat()->setFormatCode('#,##0.00');
        if ($totaux !== null) {
            $feuille->fromArray(array_values($totaux), null, 'A' . $ligne, true);
            $style = $feuille->getStyle("A{$ligne}:{$fin}{$ligne}");
            $style->getFont()->setBold(true);
            $style->getFill()->setFillType(Fill::FILL_SOLID)->getStartColor()->setRGB('E6EEF4');
            $ligne++;
        }
        return $ligne + 1;
    }

    private static function largeurs($feuille, int $nombre): void
    {
        for ($i = 0; $i < $nombre; $i++) {
            $feuille->getColumnDimension(chr(ord('A') + $i))->setAutoSize(true);
        }
    }
}
