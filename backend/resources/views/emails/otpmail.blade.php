<!DOCTYPE html
    PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="{{ App::currentLocale() }}">

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

        .otp-container {
            background-color: #3498db;
            color: #fff;
            padding: 15px;
            text-align: center;
            font-size: 24px;
            border-radius: 6px;
            margin-top: 20px;
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
        <h1>{{ __('Bonjour') }} {{ $userName }}</h1>

        <p>Pour vérifier votre compte, veuillez utiliser le code OTP suivant :</p>

        <div class="otp-container">
            <strong>{{ $otp }}</strong>
        </div>

        <p>Si vous n'avez pas demandé cette vérification, veuillez ignorer cet e-mail.</p>

        <footer>
            Cordialement<br>
            {{ env('APP_NAME') }}
        </footer>
    </div>
</body>

</html>
