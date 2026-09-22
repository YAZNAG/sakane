<?php

namespace App\Http\Middleware;

use App\Services\CataloguePermissions;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

/**
 * Controle central des droits : chaque route du tableau de bord listee
 * dans le catalogue exige l un de ses droits. Un refus s applique meme si
 * l application est contournee. Une route validee est marquee, pour que
 * les anciens controles « admin seulement » des controleurs la laissent passer.
 */
class ControleDroits
{
    public function handle(Request $request, Closure $next): Response
    {
        $route = $request->route();
        $droits = $route ? CataloguePermissions::droitsDeRoute($request->method(), $route->uri()) : null;
        if (!$droits) {
            return $next($request);
        }

        try {
            $manager = $request->user("managers");
        } catch (Throwable $th) {
            $manager = null;
        }
        // Sans utilisateur, l authentification de la route repond elle-meme.
        if (!$manager) {
            return $next($request);
        }

        if (!CataloguePermissions::peutUnDe($manager, $droits)) {
            $msg = "Vous n avez pas le droit : " . CataloguePermissions::libelle($droits[0]) . ".";
            $msg = str_replace("n avez", "n\u{2019}avez", $msg);
            return response()->json([
                "success"    => false,
                "statusCode" => 403,
                "message"    => $msg,
                "error"      => ["msg" => [$msg]],
            ], 403);
        }

        $request->attributes->set("droit_verifie", true);
        return $next($request);
    }
}
