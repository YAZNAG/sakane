<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;



return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__ . '/../routes/web.php',
        api: __DIR__ . '/../routes/api.php',
        commands: __DIR__ . '/../routes/console.php',
        channels: __DIR__ . '/../routes/channels.php',
        health: '/up',
    )->withBroadcasting(
        __DIR__ . '/../routes/channels.php',
        ['prefix' => 'api/app', 'middleware' => ['auth:sanctum']],
    )
    ->withMiddleware(function (Middleware $middleware) {
        // Les ecritures venant de l'application mobile portent une cle
        // d'idempotence ; le middleware evite les doublons apres une
        // synchronisation hors connexion.
        $middleware->api(append: [
            \App\Http\Middleware\Idempotence::class,
            // Controle central des droits : chaque route exige son droit.
            \App\Http\Middleware\ControleDroits::class,
            // Compte de démonstration (vérification Apple) : consultation seule.
            \App\Http\Middleware\LectureSeuleDemo::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        //
    })->create();
