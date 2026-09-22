<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="fr">
<head>
    <title>{{ config('app.name') }}</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <meta name="color-scheme" content="light">
    <meta name="supported-color-schemes" content="light">
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f4f4;
            color: #333;
            margin: 0;
            padding: 0;
        }
        .container {
            width: 80%;
            max-width: 600px;
            margin: 20px auto;
            background-color: #fff;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
        }
        h1 {
            color: #3498db;
            font-size: 24px;
            margin-bottom: 10px;
        }
        h2 {
            color: #2c3e50;
            font-size: 18px;
            margin-top: 20px;
            margin-bottom: 15px;
        }
        p {
            font-size: 16px;
            line-height: 1.6;
            margin-bottom: 15px;
        }
        .details-container {
            background-color: #ecf0f1;
            padding: 20px;
            border-radius: 6px;
            margin: 20px 0;
        }
        .detail-row {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid #bdc3c7;
        }
        .detail-row:last-child {
            border-bottom: none;
        }
        .detail-label {
            font-weight: bold;
            color: #2c3e50;
        }
        .detail-value {
            color: #34495e;
        }
        .amount-container {
            background-color: #3498db;
            color: #fff;
            padding: 15px;
            text-align: center;
            font-size: 28px;
            font-weight: bold;
            border-radius: 6px;
            margin: 20px 0;
        }
        .button-container {
            text-align: center;
            margin: 30px 0;
        }
        .button {
            display: inline-block;
            padding: 15px 30px;
            background-color: #27ae60;
            color: #fff;
            text-decoration: none;
            border-radius: 5px;
            font-size: 16px;
            font-weight: bold;
        }
        .button:hover {
            background-color: #229954;
        }
        footer {
            margin-top: 30px;
            text-align: center;
            font-size: 14px;
            color: #888;
            border-top: 1px solid #ecf0f1;
            padding-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>{{ $title }}</h1>
        <p>{{ $subtitle }}</p>

        <h2>Détails de la réservation</h2>
        <div class="details-container">
            <div class="detail-row">
                <span class="detail-label">Date d'arrivée :</span>
                <span class="detail-value">{{ $checkin }}</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Date de départ :</span>
                <span class="detail-value">{{ $checkout }}</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Nombre de voyageurs :</span>
                <span class="detail-value">{{ $guest }}</span>
            </div>
        </div>

        <div class="amount-container">
            Montant total : {{ $amount }}
        </div>

        <footer>
            Cordialement,<br>
            L'équipe {{ config('app.name') }}
        </footer>
    </div>
</body>
</html>
