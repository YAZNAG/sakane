<?php

namespace App\Services;

use App\Models\Booking;
use App\Models\Manager;
use Carbon\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;
use Throwable;
use WasenderApi\WasenderClient;

/** Les messages qui suivent la modification d'un contrat (prolongation, raccourcissement, prix). */
class MessagesModification
{
    /** Les essais le coupent : aucun message ne part. */
    public static bool $envoisActifs = true;

    private static function montant($v): string
    {
        return number_format((float) $v, 0, ',', ' ');
    }

    /**
     * Les variables du sejour, plus l'avant et l'apres :
     * $avant = [checkout, prixNuit, total, difference].
     */
    public static function variables(Booking $booking, array $avant = []): array
    {
        $booking->loadMissing(["client", "realestate"]);
        $v = DonneesReservation::variables($booking);
        $ancienDepart = $avant["checkout"] ?? null;
        $delta = $ancienDepart
            ? (int) round(Carbon::parse($ancienDepart)->startOfDay()->diffInDays(Carbon::parse($booking->checkout)->startOfDay(), false))
            : 0;
        $v["{old_check_out_date}"] = Carbon::parse($ancienDepart ?? $booking->checkout)->format("d/m/Y");
        $v["{nights_delta}"] = $delta > 0 ? "+" . $delta : (string) $delta;
        $v["{night_price}"] = static::montant($booking->night_price);
        $v["{old_night_price}"] = static::montant($avant["prixNuit"] ?? $booking->night_price);
        $v["{new_amount}"] = static::montant($booking->amount);
        $v["{old_amount}"] = static::montant($avant["total"] ?? $booking->amount);
        $v["{difference}"] = static::montant(abs((float) ($avant["difference"] ?? ((float) $booking->amount - (float) ($avant["total"] ?? $booking->amount)))));
        return $v;
    }

    /** Les administrateurs, l'auteur de l'operation et le createur de la reservation. */
    public static function gestionnaires(Booking $booking, $manager): Collection
    {
        $tels = Manager::role("admin")->when($manager, fn($q) => $q->where("id", "!=", $manager->id))->get()
            ->map(fn($a) => str_replace("+", "", (string) $a->phone));
        foreach ([$manager, $booking->manager] as $d) {
            $tel = str_replace("+", "", (string) ($d->phone ?? ""));
            if ($tel !== "" && !$tels->contains($tel)) $tels->push($tel);
        }
        return $tels->filter()->unique()->values();
    }

    /** Apres un changement de prix : le client et les gestionnaires recoivent le nouveau contrat. */
    public static function apresPrix(Booking $booking, $manager, array $avant): void
    {
        if (!static::$envoisActifs) {
            return;
        }
        try {
            $booking->loadMissing(["client", "realestate", "manager"]);
            $variables = static::variables($booking, $avant);
            $wa = new WasenderClient(config("services.whatsapp.wasender_key"));
            $contrat = $booking->getFirstMediaUrl("contract-private");
            $client = str_replace("+", "", (string) ($booking->client->tel ?? ""));
            if ($client !== "" && $contrat) {
                try {
                    $wa->sendDocument($client, $contrat, ModelesMessages::rendu("booking-price-client", $variables), "bulletin_hebergement.pdf");
                } catch (Throwable $th) {
                    Log::error($th);
                }
            }
            $texte = ModelesMessages::rendu("booking-price-admin", $variables);
            foreach (ReceptionWhatsapp::filtrer(static::gestionnaires($booking, $manager), "reservation-prix-modifie") as $tel) {
                try {
                    $contrat ? $wa->sendDocument($tel, $contrat, $texte, "bulletin_hebergement.pdf") : $wa->sendText($tel, $texte);
                } catch (Throwable $th) {
                    Log::error($th);
                }
            }
        } catch (Throwable $th) {
            Log::error("Messages de modification du prix : " . $th->getMessage());
        }
    }
}
