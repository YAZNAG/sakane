<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

/**
 * Le compte de démonstration (rôle « demo », utilisé par la vérification
 * d'Apple) consulte l'application sans jamais rien modifier : aucune
 * écriture en base et aucun message WhatsApp envoyé à de vrais clients.
 */
class LectureSeuleDemo
{
    /** Écritures sans effet sur les données de l'agence. */
    private const AUTORISEES = [
        "api/dashboard/export",
        "api/dashboard/accueil/disposition",
    ];

    public function handle(Request $request, Closure $next): Response
    {
        if ($request->isMethodSafe() || in_array(trim($request->path(), "/"), self::AUTORISEES, true)) {
            return $next($request);
        }

        try {
            $manager = $request->user("managers");
            $demo = $manager && method_exists($manager, "hasRole") && $manager->hasRole("demo");
        } catch (Throwable $th) {
            $demo = false;
        }

        if ($demo) {
            return response()->json([
                "success"    => false,
                "statusCode" => 403,
                "message"    => "Compte de démonstration : consultation uniquement.",
                "error"      => ["msg" => ["Compte de démonstration : consultation uniquement."]],
            ], 403);
        }

        return $next($request);
    }
}
