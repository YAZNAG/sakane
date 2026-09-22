<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: sans-serif; font-size: 11px; color: #222; }
        h1 { font-size: 17px; color: #1B3A5C; margin: 0 0 4px 0; }
        .sous { color: #666; font-size: 10px; margin-bottom: 14px; }
        table { width: 100%; border-collapse: collapse; margin-top: 8px; }
        th { background: #2E6DA4; color: #fff; text-align: left; padding: 6px; font-size: 10px; }
        td { border-bottom: 1px solid #D5DDE5; padding: 5px 6px; }
        tr:nth-child(even) td { background: #F6F8FA; }
        .pied { margin-top: 18px; font-size: 9px; color: #888; text-align: center; }
    </style>
</head>
<body>
    <h1>{{ $titre }}</h1>
    <div class="sous">
        @if(!empty($periode)) Période : {{ $periode }} — @endif
        Édité le {{ now()->format('d/m/Y à H:i') }}
    </div>

    <table>
        <thead>
            <tr>@foreach($entetes as $e)<th>{{ $e }}</th>@endforeach</tr>
        </thead>
        <tbody>
            @forelse($lignes as $ligne)
                <tr>@foreach($ligne as $cellule)<td>{{ $cellule }}</td>@endforeach</tr>
            @empty
                <tr><td colspan="{{ count($entetes) }}">Aucune donnée sur cette période.</td></tr>
            @endforelse
        </tbody>
    </table>

    <div class="pied">{{ config('app.name') }} — document généré automatiquement</div>
</body>
</html>
