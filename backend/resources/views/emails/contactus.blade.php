<!DOCTYPE html
    PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="{{ \Illuminate\Support\Facades\App::currentLocale() }}">

<head>
    <title>{{ config('app.name') }}</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <meta name="color-scheme" content="light">
    <meta name="supported-color-schemes" content="light">
    <style>
        body {
            font-family: 'Arial', sans-serif;
            background-color: #f4f4f4;
            color: #333;
            margin: 0;
            padding: 0;
            direction: {{ App::currentLocale() === 'ar' ? 'rtl' : 'ltr' }};
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
        }

        p {
            font-size: 16px;
            line-height: 1.6;
            margin-bottom: 20px;
        }

        .info-box {
            background-color: #ecf0f1;
            padding: 10px 15px;
            margin-bottom: 10px;
            border-radius: 5px;
        }

        .info-label {
            font-weight: bold;
            display: inline-block;
            width: 100px;
        }

        footer {
            margin-top: 20px;
            text-align: center;
            font-size: 14px;
            color: #888;
        }
    </style>
</head>

<body>
    <div class="container">
        <h1>Nouvelle demande de contact</h1>

        <div class="info-box">
            <span class="info-label">Email :</span> {{ $userMail }}
        </div>

        <div class="info-box">
            <span class="info-label">Téléphone :</span> {{ $userTel }}
        </div>

        <div class="info-box">
            <span class="info-label">Sujet :</span> {{ $userSubject }}
        </div>

        <p><strong>Message :</strong></p>
        <p>{{ $userMessage }}</p>

        <footer>
            Cordialement,<br>
            {{ env('APP_NAME') }}
        </footer>
    </div>
</body>

</html>
