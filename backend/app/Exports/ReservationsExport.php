<?php

namespace App\Exports;

use App\Services\ReservationsExportees;
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
 * Liste de reservations au format Excel.
 *
 * Une ligne par reservation, une ligne de totaux a la fin : c'est ce
 * qu'on attend d'un tableur, meme si l'ecran ne l'affiche pas.
 */
class ReservationsExport implements FromArray, WithHeadings, WithTitle, ShouldAutoSize, WithStyles
{
    public function __construct(private array $rows, private string $titre = "R\u{E9}servations") {}

    public function headings(): array
    {
        return ReservationsExportees::COLONNES;
    }

    public function array(): array
    {
        if (empty($this->rows)) {
            return [];
        }
        return array_merge($this->rows, [ReservationsExportees::totaux($this->rows)]);
    }

    public function title(): string
    {
        // Excel refuse les onglets de plus de 31 caracteres.
        return mb_substr($this->titre, 0, 31);
    }

    public function styles(Worksheet $sheet)
    {
        $derniere = count($this->rows) + 2;
        $colonnes = "A1:O" . max(2, $derniere);

        $sheet->getStyle("A1:O1")->applyFromArray([
            "font" => ["bold" => true, "color" => ["rgb" => "FFFFFF"]],
            "fill" => [
                "fillType" => Fill::FILL_SOLID,
                "startColor" => ["rgb" => "1F3864"],
            ],
            "alignment" => ["horizontal" => Alignment::HORIZONTAL_CENTER],
        ]);

        $sheet->getStyle($colonnes)->applyFromArray([
            "borders" => [
                "allBorders" => [
                    "borderStyle" => Border::BORDER_THIN,
                    "color" => ["rgb" => "BFBFBF"],
                ],
            ],
        ]);

        if (!empty($this->rows)) {
            $sheet->getStyle("A{$derniere}:O{$derniere}")->applyFromArray([
                "font" => ["bold" => true],
                "fill" => [
                    "fillType" => Fill::FILL_SOLID,
                    "startColor" => ["rgb" => "DDEBF7"],
                ],
            ]);
        }

        // La premiere colonne reste visible quand on fait defiler.
        $sheet->freezePane("B2");

        return [];
    }
}
