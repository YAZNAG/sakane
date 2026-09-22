<?php

namespace App\Services;

use App\Models\Booking;
use App\Models\Syndic;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;
use WasenderApi\WasenderClient;

/**
 * Envoi du contrat public aux syndics de l'immeuble : a chaque nouvelle
 * reservation dans l'un de leurs biens, puis a chaque prolongation ou
 * raccourcissement (pas pour un simple changement de prix).
 *
 * Un bien peut dependre de plusieurs syndics : chacun recoit le contrat.
 * Un echec n'annule jamais la reservation : il est note dans syndic_envois.
 */
class EnvoiSyndic
{
    /** Les essais le remplacent : fn($telephone, $contrat, $texte) ; aucun message ne part. */
    public static $envoyeur = null;

    /** Le texte qui accompagne le contrat, variables remplacees. */
    public static function message(Booking $booking, ?Syndic $syndic, ?string $modele = null, string $code = "syndic-contrat", ?array $variables = null): string
    {
        $booking->loadMissing(["client", "realestate"]);
        $variables = $variables ?? DonneesReservation::variables($booking);
        $variables["{syndic_name}"] = trim((string) ($syndic->nom ?? ""));

        $texte = $modele === null
            ? ModelesMessages::rendu($code, $variables)
            : strtr($modele, $variables);

        // Sans nom de syndic, pas de « Bonjour , ».
        return str_replace(["Bonjour ,", "Bonsoir ,"], ["Bonjour,", "Bonsoir,"], $texte);
    }

    /** Numero international en chiffres seuls ; null s'il est incomplet. */
    public static function numero(?string $brut): ?string
    {
        $chiffres = preg_replace('/\D/', '', (string) $brut);
        if (strlen($chiffres) < 10 || strlen($chiffres) > 15 || str_starts_with($chiffres, "0")) {
            return null;
        }
        return $chiffres;
    }

    /** Les syndics actifs d'un bien. */
    public static function syndicsDuBien(?int $bienId)
    {
        if (!$bienId) {
            return collect();
        }
        $ids = DB::table("realestate_syndic")->where("realestate_id", $bienId)->pluck("syndic_id");
        if ($ids->isEmpty()) {
            $ids = DB::table("realstates")->where("id", $bienId)->whereNotNull("syndic_id")->pluck("syndic_id");
        }
        return Syndic::whereIn("id", $ids)->where("actif", true)->orderBy("nom")->get();
    }

    /** Envoie le contrat a un syndic et note l'envoi. */
    private static function envoyer(Booking $booking, Syndic $syndic, string $code, string $source, ?array $variables): string
    {
        $telephone = static::numero($syndic->telephone);
        $contrat = $booking->getFirstMediaUrl("contract-public");
        $statut = "envoye";
        $erreur = null;
        $texte = null;

        if ($telephone === null) {
            $statut = "ignore";
            $erreur = "Numéro du syndic invalide.";
        } elseif (empty($contrat)) {
            $statut = "ignore";
            $erreur = "Contrat public absent.";
        } else {
            try {
                $texte = static::message($booking, $syndic, null, $code, $variables);
                if (is_callable(static::$envoyeur)) {
                    (static::$envoyeur)($telephone, $contrat, $texte);
                } else {
                    (new WasenderClient(config("services.whatsapp.wasender_key")))->sendDocument($telephone, $contrat, $texte, "contrat_location.pdf");
                }
            } catch (Throwable $th) {
                $statut = "echec";
                $erreur = mb_substr($th->getMessage(), 0, 500);
                Log::error("Envoi du contrat au syndic : " . $th->getMessage());
            }
        }

        $ligne = [
            "telephone"  => $telephone ?? $syndic->telephone,
            "statut"     => $statut,
            "erreur"     => $erreur,
            "message"    => $texte,
            "updated_at" => now(),
        ];
        if ($source === "auto") {
            DB::table("syndic_envois")->updateOrInsert(
                ["syndic_id" => $syndic->id, "booking_id" => $booking->id, "source" => "auto"],
                $ligne + ["created_at" => now()]
            );
        } else {
            // Chaque modification est un envoi a part dans l'historique.
            DB::table("syndic_envois")->insert($ligne + ["syndic_id" => $syndic->id, "booking_id" => $booking->id, "source" => $source, "created_at" => now()]);
        }
        return $statut;
    }

    public static function apresReservation(Booking $booking): ?string
    {
        try {
            $statut = null;
            foreach (static::syndicsDuBien($booking->realestate_id) as $syndic) {
                $dejaEnvoye = DB::table("syndic_envois")
                    ->where("syndic_id", $syndic->id)
                    ->where("booking_id", $booking->id)
                    ->where("source", "auto")
                    ->where("statut", "envoye")
                    ->exists();
                $statut = $dejaEnvoye ? ($statut ?? "deja") : static::envoyer($booking, $syndic, "syndic-contrat", "auto", null);
            }
            return $statut;
        } catch (Throwable $th) {
            Log::error("Envoi syndic impossible : " . $th->getMessage());
            return "echec";
        }
    }

    /** Apres une prolongation ou un raccourcissement : le nouveau contrat part aux syndics. */
    public static function apresModification(Booking $booking, string $type, array $avant = []): ?string
    {
        if (!in_array($type, ["prolongation", "raccourcissement"], true)) {
            return null;
        }
        try {
            $variables = MessagesModification::variables($booking, $avant);
            $statut = null;
            foreach (static::syndicsDuBien($booking->realestate_id) as $syndic) {
                $statut = static::envoyer($booking, $syndic, "syndic-" . $type, $type, $variables);
            }
            return $statut;
        } catch (Throwable $th) {
            Log::error("Envoi syndic apres modification impossible : " . $th->getMessage());
            return "echec";
        }
    }
}
