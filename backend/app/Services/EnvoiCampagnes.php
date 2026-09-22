<?php

namespace App\Services;

use App\Models\Campagne;
use App\Models\CampagneDestinataire;
use Illuminate\Support\Facades\Log;
use Throwable;
use WasenderApi\WasenderClient;

/**
 * L'envoi des campagnes, au rythme fixe de la campagne (2 messages par
 * minute par defaut), dans l'ordre de la liste.
 *
 * Appele chaque minute par le planificateur. Avant chaque message, l'etat
 * de la campagne est relu : une pause prend effet immediatement et les
 * messages restants gardent leur place, en attente.
 */
class EnvoiCampagnes
{
    /** Remplacables pendant les essais : l'envoi WhatsApp et l'attente. */
    public static $envoyeur = null;
    public static $attente = null;

    /** @return int nombre de messages traites pendant ce passage */
    public static function passage(): int
    {
        static::demarrerProgrammees();

        $campagne = Campagne::where("statut", "en_cours")->orderBy("demarree_a")->orderBy("id")->first();
        if (!$campagne) {
            return 0;
        }

        $parMinute = max(1, min(10, (int) ($campagne->par_minute ?: 2)));
        $intervalle = intdiv(60, $parMinute);
        $traites = 0;

        for ($i = 0; $i < $parMinute; $i++) {
            // Une pause ou une annulation compte tout de suite.
            $campagne->refresh();
            if ($campagne->statut !== "en_cours") {
                break;
            }

            $destinataire = CampagneDestinataire::where("campagne_id", $campagne->id)
                ->where("statut", "en_attente")
                ->orderByRaw("ordre IS NULL, ordre")
                ->orderBy("id")
                ->first();

            if (!$destinataire) {
                static::cloturer($campagne);
                break;
            }

            if ($i > 0) {
                static::attendre($intervalle);
                $campagne->refresh();
                if ($campagne->statut !== "en_cours") {
                    break;
                }
            }

            static::envoyer($campagne, $destinataire->fresh());
            $traites++;
        }

        static::recompter($campagne);
        if ($campagne->statut === "en_cours"
            && !CampagneDestinataire::where("campagne_id", $campagne->id)->where("statut", "en_attente")->exists()) {
            static::cloturer($campagne);
        }

        return $traites;
    }

    private static function attendre(int $secondes): void
    {
        if (is_callable(static::$attente)) {
            (static::$attente)($secondes);
            return;
        }
        sleep($secondes);
    }

    public static function envoyer(Campagne $campagne, CampagneDestinataire $d): void
    {
        if ($d->statut !== "en_attente") {
            return;
        }

        // Jamais deux fois le meme numero dans une campagne.
        $dejaServi = CampagneDestinataire::where("campagne_id", $campagne->id)
            ->where("id", "<>", $d->id)
            ->where("telephone", $d->telephone)
            ->where("statut", "envoye")
            ->exists();
        if ($dejaServi) {
            $d->update(["statut" => "ignore", "erreur" => "Numéro déjà servi dans cette campagne"]);
            return;
        }

        if (trim((string) $d->telephone) === "") {
            $d->update(["statut" => "echec", "erreur" => "Numéro de téléphone invalide", "tentatives" => $d->tentatives + 1]);
            return;
        }

        try {
            $image = $campagne->imageUrl();
            if (is_callable(static::$envoyeur)) {
                (static::$envoyeur)($d->telephone, $d->message_final, $image);
            } else {
                $wa = \App\Services\WhatsappCampagnes::client();
                if ($image) {
                    $wa->sendImage($d->telephone, $image, $d->message_final);
                } else {
                    $wa->sendText($d->telephone, $d->message_final);
                }
            }
            $d->update(["statut" => "envoye", "envoye_a" => now(), "erreur" => null, "tentatives" => $d->tentatives + 1]);
            $campagne->update(["dernier_envoi_a" => now()]);
        } catch (Throwable $th) {
            $d->update(["statut" => "echec", "erreur" => mb_substr($th->getMessage(), 0, 500), "tentatives" => $d->tentatives + 1]);
            Log::error("Campagne {$campagne->id} : envoi echoue vers {$d->telephone} - " . $th->getMessage());
        }
    }

    /** Les compteurs viennent de la liste elle-meme : ils ne derivent jamais. */
    public static function recompter(Campagne $campagne): void
    {
        $nb = CampagneDestinataire::where("campagne_id", $campagne->id)
            ->selectRaw("statut, count(*) n")->groupBy("statut")->pluck("n", "statut");
        $campagne->update([
            "nb_destinataires" => (int) $nb->sum(),
            "nb_envoyes"       => (int) ($nb["envoye"] ?? 0),
            "nb_echecs"        => (int) ($nb["echec"] ?? 0),
        ]);
    }

    private static function demarrerProgrammees(): void
    {
        Campagne::where("statut", "programmee")
            ->whereNotNull("planifiee_a")
            ->where("planifiee_a", "<=", now())
            ->get()
            ->each(fn(Campagne $c) => $c->update(["statut" => "en_cours", "demarree_a" => $c->demarree_a ?? now()]));
    }

    private static function cloturer(Campagne $campagne): void
    {
        static::recompter($campagne);
        $campagne->update(["statut" => "terminee", "terminee_a" => now()]);
    }
}
