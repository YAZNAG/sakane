<?php

namespace App\Services;

use App\Models\Manager;
use Illuminate\Support\Collection;

/**
 * Ce que chaque utilisateur accepte de recevoir sur WhatsApp, message par
 * message. Les envois aux clients et aux syndics ne sont pas concernes, ni
 * le code de reinitialisation du mot de passe.
 */
class ReceptionWhatsapp
{
    public const GROUPES = [
        "reservations" => "Réservations",
        "nettoyage"    => "Nettoyage",
        "charges"      => "Charges",
        "reclamations" => "Réclamations",
        "rappels"      => "Rappels",
    ];

    /** code => [groupe, libelle, description] */
    public const TYPES = [
        "reservation-ajoutee"     => ["reservations", "Réservation ajoutée", "Une nouvelle réservation est enregistrée."],
        "reservation-prolongee"   => ["reservations", "Réservation prolongée", "Un séjour est prolongé."],
        "reservation-raccourcie"  => ["reservations", "Réservation raccourcie", "Un séjour est raccourci."],
        "reservation-prix-modifie" => ["reservations", "Prix modifié", "Le prix d'une réservation est modifié."],
        "nettoyage-a-faire"       => ["nettoyage", "Appartement à nettoyer", "Un appartement est libéré et doit être nettoyé."],
        "nettoyage-commence"      => ["nettoyage", "Nettoyage commencé", "Un nettoyage démarre."],
        "nettoyage-termine"       => ["nettoyage", "Nettoyage terminé", "Un nettoyage est terminé."],
        "charge-ajoutee"          => ["charges", "Charge ajoutée", "Une nouvelle charge est saisie."],
        "charge-traitee"          => ["charges", "Charge traitée", "Une charge est validée."],
        "charge-programmee"       => ["charges", "Charge programmée", "Rappel d'une charge programmée."],
        "reclamation-ajoutee"     => ["reclamations", "Réclamation ajoutée", "Une nouvelle réclamation est signalée."],
        "reclamation-resolue"     => ["reclamations", "Réclamation résolue", "Une réclamation est traitée."],
        "rappels"                 => ["rappels", "Rappels d'arrivée", "Rappels des arrivées de vos clients."],
    ];

    /** Les codes d'un groupe, ou le code lui-meme. */
    private static function codes(string $type): array
    {
        if (isset(self::TYPES[$type])) {
            return [$type];
        }
        return array_keys(array_filter(self::TYPES, fn($t) => $t[0] === $type));
    }

    public static function typesCoupes(Manager $m): array
    {
        $coupes = $m->whatsapp_types_coupes;
        if (is_string($coupes)) {
            $coupes = json_decode($coupes, true);
        }
        $fins = [];
        foreach ((array) ($coupes ?? []) as $c) {
            foreach (static::codes((string) $c) as $f) $fins[] = $f;
        }
        return array_values(array_unique($fins));
    }

    public static function accepte(?Manager $m, string $type): bool
    {
        if (!$m) {
            return true;
        }
        if (!(bool) ($m->whatsapp_actif ?? true)) {
            return false;
        }
        $codes = static::codes($type);
        // Un groupe n'est refuse que si tous ses messages le sont.
        return $codes === [] || count(array_diff($codes, static::typesCoupes($m))) > 0;
    }

    /** Les 9 derniers chiffres : la meme personne, quel que soit le format saisi. */
    private static function cle(?string $tel): string
    {
        $chiffres = preg_replace('/\D/', '', (string) $tel);
        return strlen($chiffres) >= 9 ? substr($chiffres, -9) : $chiffres;
    }

    /** Retire des numeros ceux des utilisateurs qui refusent ce type de message. */
    public static function filtrer($telephones, string $type): Collection
    {
        $telephones = collect($telephones);
        if ($telephones->isEmpty()) {
            return $telephones;
        }

        $refus = Manager::query()
            ->where(fn($q) => $q->where("whatsapp_actif", false)->orWhereNotNull("whatsapp_types_coupes"))
            ->get(["id", "phone", "whatsapp_actif", "whatsapp_types_coupes"])
            ->filter(fn($m) => !static::accepte($m, $type))
            ->map(fn($m) => static::cle($m->phone))
            ->filter()
            ->flip();

        if ($refus->isEmpty()) {
            return $telephones->values();
        }

        return $telephones->reject(fn($t) => isset($refus[static::cle($t)]))->values();
    }

    public static function reglages(Manager $m): array
    {
        $coupes = static::typesCoupes($m);
        return [
            "managerId" => $m->id,
            "nom"       => trim(($m->first_name ?? "") . " " . ($m->last_name ?? "")),
            "telephone" => $m->phone,
            "actif"     => (bool) ($m->whatsapp_actif ?? true),
            "groupes"   => collect(self::GROUPES)->map(fn($libelle, $code) => ["code" => $code, "libelle" => $libelle])->values(),
            "types"     => collect(self::TYPES)->map(fn($t, $code) => [
                "code"        => $code,
                "groupe"      => $t[0],
                "groupeLibelle" => self::GROUPES[$t[0]] ?? $t[0],
                "libelle"     => $t[1],
                "description" => $t[2],
                "actif"       => !in_array($code, $coupes, true),
            ])->values(),
        ];
    }
}
