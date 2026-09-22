<?php

namespace App\Exports;

use Maatwebsite\Excel\Concerns\FromArray;
use Maatwebsite\Excel\Concerns\ShouldAutoSize;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithStyles;
use Maatwebsite\Excel\Concerns\WithTitle;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Border;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Worksheet\Worksheet;

/**
 * Comparatif financier au format Excel.
 *
 * Le fichier reprend colonne pour colonne le tableau affiche dans
 * l'ecran des statistiques : celui qui exporte doit retrouver ce qu'il
 * avait sous les yeux, dans le meme ordre et avec les memes intitules.
 *
 * S'y ajoute une ligne de totaux, que l'ecran n'affiche pas mais qu'on
 * attend d'un tableur.
 */
class ComparativeExport implements FromArray, WithHeadings, WithTitle, ShouldAutoSize, WithStyles
{
    public function __construct(private array $rows) {}

    public function headings(): array
    {
        // Memes intitules que le tableau a l'ecran.
        return [
            'Appartement',
            'Jours Rés.',
            'Jours Lib.',
            'CA (MAD)',
            'Dép. (MAD)',
            'Remb. (MAD)',
            'Annul. (MAD)',
            'Bénéfice (MAD)',
        ];
    }

    public function array(): array
    {
        $lignes = array_map(fn($r) => [
            $r['title'] ?? '',
            (int) ($r['reservedDays'] ?? 0),
            (int) ($r['nonReservedDays'] ?? 0),
            round((float) ($r['revenue'] ?? 0), 2),
            round((float) ($r['expenses'] ?? 0), 2),
            round((float) ($r['refunds'] ?? 0), 2),
            round((float) ($r['cancellations'] ?? 0), 2),
            round((float) ($r['profit'] ?? 0), 2),
        ], $this->rows);

        if (empty($lignes)) {
            return $lignes;
        }

        // Ligne de totaux : les jours ne s'additionnent pas de facon
        // parlante d'un bien a l'autre, seuls les montants le sont.
        $lignes[] = [
            'TOTAL',
            '',
            '',
            round(array_sum(array_column($lignes, 3)), 2),
            round(array_sum(array_column($lignes, 4)), 2),
            round(array_sum(array_column($lignes, 5)), 2),
            round(array_sum(array_column($lignes, 6)), 2),
            round(array_sum(array_column($lignes, 7)), 2),
        ];

        return $lignes;
    }

    public function styles(Worksheet $feuille): array
    {
        $derniere = count($this->rows) + 2; // en-tete + lignes + totaux

        // En-tete : fond de la couleur de l'application, texte blanc.
        $feuille->getStyle('A1:H1')->applyFromArray([
            'font' => ['bold' => true, 'color' => ['rgb' => 'FFFFFF']],
            'fill' => [
                'fillType' => Fill::FILL_SOLID,
                'startColor' => ['rgb' => '1976D2'],
            ],
            'alignment' => [
                'horizontal' => Alignment::HORIZONTAL_CENTER,
                'vertical' => Alignment::VERTICAL_CENTER,
            ],
        ]);
        $feuille->getRowDimension(1)->setRowHeight(24);

        // La premiere colonne reste lisible en parcourant le tableau,
        // comme la colonne figee a l'ecran.
        $feuille->freezePane('B2');

        if (!empty($this->rows)) {
            $feuille->getStyle("A{$derniere}:H{$derniere}")->applyFromArray([
                'font' => ['bold' => true],
                'fill' => [
                    'fillType' => Fill::FILL_SOLID,
                    'startColor' => ['rgb' => 'ECECF7'],
                ],
                'borders' => [
                    'top' => ['borderStyle' => Border::BORDER_THIN],
                ],
            ]);

            // Montants alignes a droite et affiches avec deux decimales.
            $feuille->getStyle("D2:H{$derniere}")
                ->getNumberFormat()->setFormatCode('#,##0.00');
            $feuille->getStyle("B2:H{$derniere}")
                ->getAlignment()->setHorizontal(Alignment::HORIZONTAL_RIGHT);
        }

        return [];
    }

    public function title(): string
    {
        return 'Comparatif';
    }
}
