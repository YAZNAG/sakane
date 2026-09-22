<?php

namespace App\Console\Commands;

use App\Models\Booking;
use App\Models\Rappel;
use App\Models\RappelEnvoye;
use App\Services\DonneesReservation;
use App\Services\EnvoiRappel;
use App\Services\ModelesMessages;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Throwable;
use WasenderApi\WasenderClient;

/**
 * Envoie les rappels dont l'heure est venue.
 *
 * Le rendez-vous de chaque rappel est calcule a partir de l'arrivee ou
 * du depart, decale du nombre d'heures configure. Une fenetre de
 * rattrapage evite de perdre un envoi si le planificateur a pris du
 * retard, sans pour autant reveiller de vieux rappels.
 */
class EnvoyerRappels extends Command
{
    protected $signature = 'rappels:envoyer {--fenetre=6 : heures de rattrapage}';

    protected $description = "Envoie les rappels de reservation et les messages post-sejour";

    public function handle(): int
    {
        $fenetre = max(1, (int) $this->option('fenetre'));
        // Un rappel declenche a la main n'a pas de rendez-vous a
        // surveiller : le message post-sejour part au constat du depart.
        $rappels = Rappel::where('actif', true)
            ->whereIn('moment', [Rappel::MOMENT_ARRIVEE, Rappel::MOMENT_DEPART])
            ->orderBy('ordre')->get();

        if ($rappels->isEmpty()) {
            return self::SUCCESS;
        }

        $wa = new WasenderClient(config('services.whatsapp.wasender_key'));
        $total = 0;

        foreach ($rappels as $rappel) {
            $total += $this->traiter($rappel, $wa, $fenetre);
        }

        if ($total > 0) {
            $this->info("{$total} rappel(s) traite(s).");
        }
        return self::SUCCESS;
    }

    private function traiter(Rappel $rappel, WasenderClient $wa, int $fenetre): int
    {
        $colonne = $rappel->moment === 'checkin' ? 'checkin' : 'checkout';

        // Un rappel a -72 h se declenche quand la date de reference est
        // dans 72 h. On cherche donc les reservations dont la reference
        // tombe dans la fenetre [maintenant - decalage - rattrapage ;
        // maintenant - decalage].
        $cible    = now()->copy()->subHours($rappel->decalage_heures);
        $debut    = $cible->copy()->subHours($fenetre);

        $bookings = Booking::with(['client', 'realestate.city', 'status'])
            ->whereBetween($colonne, [$debut, $cible])
            ->get();

        $traites = 0;

        foreach ($bookings as $booking) {
            if (!$this->reservationEligible($booking, $rappel)) {
                continue;
            }

            $variables = DonneesReservation::variables($booking);

            if ($rappel->vers_client) {
                $traites += $this->envoyer($rappel, $booking, 'client',
                    $booking->client->tel ?? null,
                    $rappel->modele_client, $variables, $wa);
            }

            if ($rappel->vers_agent && \App\Services\ReceptionWhatsapp::accepte($booking->manager ?? null, "rappels")) {
                $agent = $booking->manager ?? null;
                $traites += $this->envoyer($rappel, $booking, 'agent',
                    $agent->phone ?? null,
                    $rappel->modele_agent, $variables, $wa);
            }
        }

        return $traites;
    }

    /**
     * Un message post-sejour n'a de sens que si le sejour s'est termine
     * normalement : une reservation annulee ne doit rien declencher.
     */
    private function reservationEligible(Booking $booking, Rappel $rappel): bool
    {
        $statut = $booking->status->code ?? null;

        if ($rappel->moment === 'checkout') {
            return in_array($statut, ['completed', 'payed', 'termine'], true);
        }

        return !in_array($statut, ['canceled', 'cancelled', 'refunded'], true);
    }

    private function envoyer(Rappel $rappel, Booking $booking, string $destinataire,
                             ?string $telephone, ?string $codeModele,
                             array $variables, WasenderClient $wa): int
    {
        return EnvoiRappel::envoyer($rappel, $booking, $destinataire,
            $telephone, $codeModele, $variables, $wa);
    }
}
