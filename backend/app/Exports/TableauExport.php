<?php

namespace App\Exports;

use Maatwebsite\Excel\Concerns\FromArray;
use Maatwebsite\Excel\Concerns\ShouldAutoSize;
use Maatwebsite\Excel\Concerns\WithCustomStartCell;
use Maatwebsite\Excel\Concerns\WithDrawings;
use Maatwebsite\Excel\Concerns\WithEvents;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithTitle;
use Maatwebsite\Excel\Events\AfterSheet;
use PhpOffice\PhpSpreadsheet\Cell\Coordinate;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Border;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Worksheet\Drawing;
use PhpOffice\PhpSpreadsheet\Worksheet\PageSetup;

/**
 * Un tableau quelconque de l'application, au format Excel.
 *
 * En haut, l'en-tete de l'agence : logo, nom, titre, periode et date
 * d'export. Dessous, le tableau : en-tete colore, lignes alternees,
 * montants au format monetaire, ligne de totaux.
 *
 * Les montants arrivent comme du texte : ceux qui sont de vrais nombres
 * redeviennent des nombres, pour que le tableur sache les additionner.
 * Un numero de telephone qui commence par 0 reste du texte.
 */
class TableauExport implements FromArray, WithHeadings, WithTitle, ShouldAutoSize, WithCustomStartCell, WithDrawings, WithEvents
{
    /** Ligne des intitules de colonnes : l'en-tete de l'agence occupe les lignes au-dessus. */
    private const LIGNE_ENTETE = 6;

    public function __construct(
        private string $titre,
        private string $sousTitre,
        private array $colonnes,
        private array $lignes,
        private ?array $totaux,
        private array $agence,
    ) {}

    public function startCell(): string
    {
        return 'A' . self::LIGNE_ENTETE;
    }

    public function headings(): array
    {
        return $this->colonnes;
    }

    public function title(): string
    {
        // Excel refuse certains caracteres et plus de 31 signes.
        $propre = trim(preg_replace('/[\\\\\/\?\*\[\]:]/', ' ', $this->titre));
        return mb_substr($propre !== "" ? $propre : "Export", 0, 31);
    }

    public function array(): array
    {
        $lignes = array_map(fn($l) => array_map([$this, 'valeur'], $l), $this->lignes);

        if ($this->totaux !== null) {
            $lignes[] = array_map([$this, 'valeur'], $this->totaux);
        }

        return $lignes;
    }

    private function valeur($v)
    {
        $v = (string) $v;
        if (preg_match('/^-?\d+(\.\d+)?$/', $v) && !(strlen($v) > 1 && $v[0] === '0' && $v[1] !== '.')) {
            return $v + 0;
        }
        return $v;
    }

    public function drawings()
    {
        if (empty($this->agence['logo'])) {
            return [];
        }

        $logo = new Drawing();
        $logo->setName('Logo');
        $logo->setDescription($this->agence['nom'] ?? 'Logo');
        $logo->setPath($this->agence['logo']);
        $logo->setHeight(68);
        $logo->setCoordinates('A1');
        $logo->setOffsetX(6);
        $logo->setOffsetY(4);

        return [$logo];
    }

    public function registerEvents(): array
    {
        return [
            AfterSheet::class => function (AfterSheet $event) {
                $feuille = $event->sheet->getDelegate();
                $couleur = $this->agence['couleur'] ?? '1F5F8B';

                $nbColonnes     = max(1, count($this->colonnes));
                $derniere       = Coordinate::stringFromColumnIndex($nbColonnes);
                $ligneEntete    = self::LIGNE_ENTETE;
                $premiereDonnee = $ligneEntete + 1;
                $nbLignes       = count($this->lignes);
                $derniereLigne  = $ligneEntete + $nbLignes + ($this->totaux !== null ? 1 : 0);

                // En-tete de l'agence, a droite du logo.
                // Le titre occupe toute la largeur du tableau, centre.
                $debutTexte = 'A';
                $zone = fn(int $l) => $debutTexte . $l . ':' . ($nbColonnes >= 3 ? $derniere : $derniere) . $l;

                $textes = [
                    1 => [mb_strtoupper($this->agence['nom'] ?? ''), 11, true, $couleur],
                    2 => [$this->titre, 16, true, '17262E'],
                    3 => [$this->sousTitre, 10, false, '4A5B64'],
                    4 => ['Exporté le ' . now()->format('d/m/Y à H:i') . ' — ' . $nbLignes . ' ligne' . ($nbLignes > 1 ? 's' : ''), 9, false, '6B7B84'],
                ];
                foreach ($textes as $l => [$texte, $taille, $gras, $teinte]) {
                    $feuille->setCellValue($debutTexte . $l, $texte);
                    if ($nbColonnes >= 2) {
                        $feuille->mergeCells($zone($l));
                    }
                    $feuille->getStyle($debutTexte . $l)->applyFromArray([
                        'font'      => ['size' => $taille, 'bold' => $gras, 'color' => ['rgb' => $teinte]],
                        'alignment' => ['horizontal' => Alignment::HORIZONTAL_CENTER, 'vertical' => Alignment::VERTICAL_CENTER],
                    ]);
                }
                $feuille->getRowDimension(1)->setRowHeight(18);
                $feuille->getRowDimension(2)->setRowHeight(24);
                $feuille->getRowDimension(3)->setRowHeight(16);
                $feuille->getRowDimension(4)->setRowHeight(16);

                // Filet de la couleur de l'application sous l'en-tete.
                $feuille->getStyle("A5:{$derniere}5")->applyFromArray([
                    'borders' => ['bottom' => ['borderStyle' => Border::BORDER_THICK, 'color' => ['rgb' => $couleur]]],
                ]);
                $feuille->getRowDimension(5)->setRowHeight(6);

                // Intitules des colonnes.
                $feuille->getStyle("A{$ligneEntete}:{$derniere}{$ligneEntete}")->applyFromArray([
                    'font'      => ['bold' => true, 'color' => ['rgb' => 'FFFFFF']],
                    'fill'      => ['fillType' => Fill::FILL_SOLID, 'startColor' => ['rgb' => $couleur]],
                    'alignment' => ['horizontal' => Alignment::HORIZONTAL_CENTER, 'vertical' => Alignment::VERTICAL_CENTER, 'wrapText' => true],
                ]);
                $feuille->getRowDimension($ligneEntete)->setRowHeight(24);

                if ($derniereLigne >= $premiereDonnee) {
                    // Bordures fines et lignes alternees.
                    $feuille->getStyle("A{$ligneEntete}:{$derniere}{$derniereLigne}")->applyFromArray([
                        'borders' => ['allBorders' => ['borderStyle' => Border::BORDER_THIN, 'color' => ['rgb' => 'DFE6EA']]],
                    ]);
                    for ($l = $premiereDonnee; $l < $premiereDonnee + $nbLignes; $l++) {
                        if (($l - $premiereDonnee) % 2 === 1) {
                            $feuille->getStyle("A{$l}:{$derniere}{$l}")->getFill()
                                ->setFillType(Fill::FILL_SOLID)->getStartColor()->setRGB('F4F7F9');
                        }
                    }

                    // Montants au format monetaire, colonne par colonne.
                    foreach (array_keys($this->colonnes) as $i) {
                        $valeurs = array_filter(array_column($this->lignes, $i), fn($v) => $v !== '' && $v !== null && $v !== '-');
                        $montants = !empty($valeurs) && count(array_filter($valeurs, fn($v) => preg_match('/^-?\d+\.\d{1,2}$/', (string) $v))) === count($valeurs);
                        if ($montants) {
                            $lettre = Coordinate::stringFromColumnIndex($i + 1);
                            $feuille->getStyle("{$lettre}{$premiereDonnee}:{$lettre}{$derniereLigne}")
                                ->getNumberFormat()->setFormatCode('#,##0.00');
                            $feuille->getStyle("{$lettre}{$premiereDonnee}:{$lettre}{$derniereLigne}")
                                ->getAlignment()->setHorizontal(Alignment::HORIZONTAL_RIGHT);
                        }
                    }

                    $feuille->setAutoFilter("A{$ligneEntete}:{$derniere}" . ($ligneEntete + $nbLignes));
                }

                if ($this->totaux !== null) {
                    $feuille->getStyle("A{$derniereLigne}:{$derniere}{$derniereLigne}")->applyFromArray([
                        'font'    => ['bold' => true, 'color' => ['rgb' => '17262E']],
                        'fill'    => ['fillType' => Fill::FILL_SOLID, 'startColor' => ['rgb' => 'E6EEF4']],
                        'borders' => [
                            'top'    => ['borderStyle' => Border::BORDER_MEDIUM, 'color' => ['rgb' => $couleur]],
                            'bottom' => ['borderStyle' => Border::BORDER_MEDIUM, 'color' => ['rgb' => $couleur]],
                        ],
                    ]);
                }

                // Le logo tient dans la premiere colonne.
                if (!empty($this->agence['logo'])) {
                    $feuille->getColumnDimension('A')->setAutoSize(false);
                    $feuille->getColumnDimension('A')->setWidth(max(16, $feuille->getColumnDimension('A')->getWidth()));
                }

                $feuille->freezePane('A' . $premiereDonnee);

                // Impression : une page en largeur, paysage si le tableau est large.
                $mise = $feuille->getPageSetup();
                $mise->setOrientation($nbColonnes > 5 ? PageSetup::ORIENTATION_LANDSCAPE : PageSetup::ORIENTATION_PORTRAIT);
                $mise->setPaperSize(PageSetup::PAPERSIZE_A4);
                $mise->setFitToWidth(1);
                $mise->setFitToHeight(0);
                $mise->setRowsToRepeatAtTopByStartAndEnd($ligneEntete, $ligneEntete);
            },
        ];
    }
}
