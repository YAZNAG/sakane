<?php

namespace App\Services;

use App\Models\Booking;
use App\Models\Rappel;
use App\Models\RappelEnvoye;
use Illuminate\Support\Facades\Log;
use Throwable;
use WasenderApi\WasenderClient;

/**
 * L'envoi d'un rappel a un destinataire.
 *
 * Le planificateur s'en sert pour les rappels cales sur une date ; le
 * constat du depart s'en sert pour le message post-sejour. Une seule
 * implementation, pour que le suivi des envois et le traitement des
 * echecs soient les memes des deux cotes.
 */
class EnvoiRappel
{
    /**
     * Le message de remerciement, au moment ou le depart est constate.
     *
     * L'appelant confirme un depart : son geste ne doit pas echouer
     * parce qu'un message n'est pas parti. Tout est donc rattrape ici.
     */
    public static function postSejour(?Booking $booking): void
    {
        if ($booking === null) {
            return;
        }

        try {
            $rappel = Rappel::where("code", "post-sejour")->first();

            if (!$rappel || !$rappel->actif || !$rappel->vers_client) {
                return;
            }

            $booking->loadMissing(["client", "realestate.city", "status"]);

            // Un sejour annule ne merite pas de remerciements.
            $statut = $booking->status->code ?? null;
            if (in_array($statut, ["canceled", "cancelled", "refunded"], true)) {
                return;
            }

            static::envoyer(
                $rappel,
                $booking,
                "client",
                $booking->client->tel ?? null,
                $rappel->modele_client,
                DonneesReservation::variables($booking)
            );
        } catch (Throwable $th) {
            Log::error("Message post-sejour au depart (reservation {$booking->id}) : "
                . $th->getMessage());
        }
    }

    /**
     * Envoie un rappel, une fois et une seule.
     *
     * @return int 1 si le rappel a ete traite, 0 s'il l'avait deja ete.
     */
    public static function envoyer(
        Rappel   $rappel,
        Booking  $booking,
        string   $destinataire,
        ?string  $telephone,
        ?string  $codeModele,
        array    $variables,
        ?WasenderClient $wa = null
    ): int {
        $numero = preg_replace('/[^0-9]/', '', (string) $telephone);

        // La contrainte d'unicite garantit qu'un rappel ne part qu'une
        // fois par reservation et par destinataire.
        $suivi = RappelEnvoye::firstOrCreate(
            [
                'booking_id'   => $booking->id,
                'rappel_id'    => $rappel->id,
                'destinataire' => $destinataire,
            ],
            ['telephone' => $numero, 'statut' => 'a_envoyer']
        );

        if ($suivi->statut === 'envoye') {
            return 0;
        }

        if (!$codeModele || $numero === '') {
            $suivi->update([
                'statut' => 'echec',
                'erreur' => $numero === ''
                    ? "Aucun num\u{E9}ro de t\u{E9}l\u{E9}phone"
                    : "Aucun mod\u{E8}le de message associ\u{E9}",
                'tentatives' => $suivi->tentatives + 1,
            ]);
            return 1;
        }

        try {
            $wa ??= new WasenderClient(config('services.whatsapp.wasender_key'));

            $texte = ModelesMessages::rendu($codeModele, $variables);
            if (trim($texte) === '') {
                throw new \RuntimeException("Mod\u{E8}le vide");
            }

            // Une image jointe au modele accompagne le texte.
            $image = ModelesMessages::image($codeModele);
            if ($image) {
                $wa->sendImage($numero, $image, $texte);
            } else {
                $wa->sendText($numero, $texte);
            }

            $suivi->update([
                'statut'     => 'envoye',
                'envoye_a'   => now(),
                'erreur'     => null,
                'telephone'  => $numero,
                'tentatives' => $suivi->tentatives + 1,
            ]);
        } catch (Throwable $th) {
            $suivi->update([
                'statut'     => 'echec',
                'erreur'     => substr($th->getMessage(), 0, 500),
                'tentatives' => $suivi->tentatives + 1,
            ]);
            Log::error("Rappel {$rappel->code} vers {$destinataire} echoue "
                . "(reservation {$booking->id}) : " . $th->getMessage());
        }

        return 1;
    }
}
