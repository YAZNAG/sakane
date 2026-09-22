<?php

namespace App\Http\Middleware;

use App\Models\IdempotentRequest;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Empeche qu'une operation enregistree hors connexion, puis renvoyee
 * plusieurs fois, ne soit executee plus d'une fois.
 *
 * L'application joint un en-tete X-Idempotency-Key propre a chaque
 * operation, des son premier envoi. La reponse de la premiere execution
 * est conservee et restituee telle quelle aux renvois suivants.
 *
 * Un verrou empeche deux envois simultanes de la meme operation d'etre
 * executes tous les deux. Les refus d'authentification ne sont pas
 * memorises : l'operation doit pouvoir repartir apres reconnexion.
 */
class Idempotence
{
    /** Reponses non memorisees : l'operation doit pouvoir etre retentee. */
    private const NON_MEMORISEES = [401, 403, 408, 419, 429];

    public function handle(Request $request, Closure $next)
    {
        $cle = $request->header("X-Idempotency-Key");

        if (!$cle || !in_array($request->method(), ["POST", "PUT", "PATCH", "DELETE"])) {
            return $next($request);
        }

        $deja = IdempotentRequest::where("cle", $cle)->first();
        if ($deja) {
            return $this->rejouer($deja);
        }

        $verrou = Cache::lock("idempotence:" . sha1($cle), 180);
        if (!$verrou->get()) {
            return response()->json([
                "success"    => false,
                "statusCode" => 409,
                "message"    => "Cette opération est déjà en cours de traitement.",
                "error"      => ["msg" => ["Cette opération est déjà en cours de traitement."]],
            ], 409)->header("X-Idempotent-En-Cours", "1");
        }

        try {
            // Un envoi concurrent a pu terminer pendant l'attente du verrou.
            $deja = IdempotentRequest::where("cle", $cle)->first();
            if ($deja) {
                return $this->rejouer($deja);
            }

            $reponse = $next($request);
            $code = $reponse->getStatusCode();

            // Les erreurs serveur et les refus d'authentification ne sont pas
            // memorises : l'operation doit pouvoir etre retentee plus tard.
            if ($code < 500 && !in_array($code, self::NON_MEMORISEES, true)) {
                try {
                    IdempotentRequest::create([
                        "cle"         => $cle,
                        "methode"     => $request->method(),
                        "chemin"      => substr($request->path(), 0, 191),
                        "status_code" => $code,
                        "reponse"     => $reponse->getContent(),
                        "manager_id"  => $request->user()?->id,
                    ]);
                } catch (Throwable $th) {
                    Log::info("Idempotence : cle deja enregistree (" . $cle . ")");
                }
            }

            return $reponse;
        } finally {
            $verrou->release();
        }
    }

    private function rejouer(IdempotentRequest $deja)
    {
        return response($deja->reponse, $deja->status_code)
            ->header("Content-Type", "application/json")
            ->header("X-Idempotent-Replay", "1");
    }
}
