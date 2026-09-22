<?php

namespace App\Exports;

use Maatwebsite\Excel\Concerns\FromArray;
use Maatwebsite\Excel\Concerns\ShouldAutoSize;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithTitle;

class StatistiquesExport implements FromArray, WithHeadings, WithTitle, ShouldAutoSize
{
    public function __construct(
        private array $rows,
        private array $entetes,
        private string $titre = 'Statistiques'
    ) {}

    public function headings(): array
    {
        return $this->entetes;
    }

    public function array(): array
    {
        return $this->rows;
    }

    public function title(): string
    {
        return $this->titre;
    }
}
