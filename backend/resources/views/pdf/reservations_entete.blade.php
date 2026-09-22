<style>
    @page { margin: 12mm 8mm; }
    body { font-family: sans-serif; font-size: 8.5pt; color: #222; }
    h1 { font-size: 15pt; margin: 0 0 2mm 0; color: #1F3864; }
    .sous-titre { font-size: 9pt; color: #666; margin-bottom: 4mm; }
    table { width: 100%; border-collapse: collapse; }
    th { background: #1F3864; color: #fff; font-size: 7.5pt; padding: 2mm 1.2mm; text-align: left; font-weight: bold; }
    td { padding: 1.6mm 1.2mm; border-bottom: 0.2mm solid #d8d8d8; }
    td.num { text-align: right; }
    th.num { text-align: right; }
    .total td { background: #DDEBF7; font-weight: bold; border-top: 0.4mm solid #1F3864; }
    .vide { padding: 12mm 0; text-align: center; color: #888; font-size: 10pt; }
    .pied { margin-top: 4mm; font-size: 7.5pt; color: #888; }
</style>
<h1>{{ $titre }}</h1>
<div class="sous-titre">{{ $sousTitre }} &mdash; {{ $nombre }} r&eacute;servation{{ $nombre > 1 ? 's' : '' }} &mdash; &eacute;dit&eacute; le {{ $editeLe }}</div>
@if ($nombre === 0)
<div class="vide">Aucune r&eacute;servation ne correspond &agrave; cette s&eacute;lection.</div>
@else
<table>
<thead><tr>@foreach ($colonnes as $i => $colonne)<th class="{{ $i >= 10 && $i <= 13 ? 'num' : '' }}">{{ $colonne }}</th>@endforeach</tr></thead>
<tbody>
@endif
