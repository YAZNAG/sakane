<?php

namespace App\Services;

use App\Models\Booking;
use App\Services\Telephone;

/**
 * Rassemble les valeurs des variables utilisees par les rappels.
 *
 * Un seul endroit decide de ce que valent {balance}, {check_in_time}
 * ou {contact} : le message au client et celui a l'agent restent ainsi
 * coherents entre eux.
 */
class DonneesReservation
{
    public static function variables(Booking $booking): array
    {
        $booking->loadMissing(["client", "realestate.city", "realestate.dossier", "manager"]);
        $client     = $booking->client;
        $realestate = $booking->realestate;
        $agent      = $booking->manager ?? null;

        $montant = (float) ($booking->amount ?? 0);
        $avance  = (float) ($booking->avance ?? 0);
        $reste   = max(0, $montant - $avance);

        return [
            "{client_name}"  => trim(($client->first_name ?? '') . ' ' . ($client->last_name ?? '')),
            "{client_phone}" => Telephone::local($client->tel ?? ''),
            "{client_cin}"   => $client->identity_number ?? '',
            "{client_email}" => $client->email ?? '',

            "{apartment_name}" => $realestate->title ?? '',
            "{address}"        => trim(($realestate->address ?? '') . ' ' .
                                       ($realestate->city->name ?? '')),
            "{city}"           => $realestate->city->name ?? '',
            "{residence}"      => $realestate->dossier->nom ?? '',
            "{rooms}"          => (string) ($realestate->nb_rooms ?? ''),

            "{booking_id}"     => (string) $booking->id,
            "{guests}"         => (string) ($booking->nb_guest ?? ''),
            "{guest_type}"     => (string) ($booking->type_guest ?? ''),

            "{check_in_date}"  => static::date($booking->checkin),
            "{check_in_time}"  => HeuresSejour::arrivee($booking),
            "{check_out_time}" => HeuresSejour::depart($booking),
            "{check_out_date}" => static::date($booking->checkout),
            "{nights}"         => (string) ($booking->nb_days ?? 0),

            "{amount}"  => number_format($montant, 0, ',', ' '),
            "{advance}" => number_format($avance, 0, ',', ' '),
            "{balance}" => number_format($reste, 0, ',', ' '),
            "{deposit}" => number_format((float) ($booking->caution ?? 0), 0, ',', ' '),

            "{notes}"   => $booking->remarques ?: 'Aucune remarque',
            "{agent_name}" => $agent
                ? trim(($agent->first_name ?? '') . ' ' . ($agent->last_name ?? ''))
                : '',

            "{contact}" => static::contactAgence(),
            "{checkin_instructions}" => static::consignesArrivee(),
        ];
    }

    /**
     * Met une date au format francais.
     *
     * Le modele ne convertit pas systematiquement ces colonnes : selon
     * le chemin, on recoit un objet date ou une chaine. On accepte les
     * deux plutot que de supposer.
     */
    private static function date($valeur): string
    {
        if (empty($valeur)) {
            return '';
        }
        try {
            return $valeur instanceof \DateTimeInterface
                ? $valeur->format('d/m/Y')
                : \Carbon\Carbon::parse((string) $valeur)->format('d/m/Y');
        } catch (\Throwable $th) {
            return (string) $valeur;
        }
    }

    /** Heure d'arrivee : valeur d'agence, faute de champ par appartement. */
    private static function heureArrivee($realestate): string
    {
        return config('agence.heure_checkin', '14h00');
    }

    private static function contactAgence(): string
    {
        return config('agence.contact', '');
    }

    private static function consignesArrivee(): string
    {
        return config('agence.consignes_checkin',
            "Merci de nous prévenir de votre heure d'arrivée.");
    }
}
