<?php

namespace App\Services;

use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Throwable;

/**
 * Synchronisation avec Airbnb par les liens de calendrier (iCal).
 *
 * Airbnb -> application : le calendrier de l'annonce est lu regulierement ;
 * ses sejours et ses dates bloquees rendent le bien indisponible ici.
 *
 * Application -> Airbnb : chaque bien a un lien prive (avec une cle
 * secrete) qu'Airbnb importe ; il contient les reservations, blocages et
 * baux de l'application, sans aucun nom de client.
 *
 * Les dates sont des nuits : un sejour du 10 au 13 occupe les nuits du
 * 10, 11 et 12 (DTEND est exclu, comme dans iCal).
 */
class SyncAirbnb
{
    /** Le calendrier d'un bien, cree avec sa cle d'export au premier besoin. */
    public static function pour(int $bienId): object
    {
        $ligne = DB::table("airbnb_calendriers")->where("realestate_id", $bienId)->first();
        if (!$ligne) {
            DB::table("airbnb_calendriers")->insert([
                "realestate_id" => $bienId,
                "jeton_export"  => Str::random(48),
                "created_at"    => now(),
                "updated_at"    => now(),
            ]);
            $ligne = DB::table("airbnb_calendriers")->where("realestate_id", $bienId)->first();
        }
        return $ligne;
    }

    public static function lienExport(object $cal): string
    {
        return rtrim(config("app.url"), "/") . "/api/dashboard/calendrier-airbnb/" . $cal->jeton_export . ".ics";
    }

    /** Lit le calendrier Airbnb d'un bien ; renvoie le nombre de sejours retenus. */
    public static function importer(object $cal): int
    {
        if (empty($cal->url_import)) {
            return 0;
        }
        try {
            $rep = Http::timeout(25)->withHeaders(["User-Agent" => "Mozilla/5.0 (calendrier)"])->get($cal->url_import);
            if (!$rep->successful()) {
                throw new \RuntimeException("Airbnb a répondu " . $rep->status() . ". Vérifiez le lien.");
            }
            $texte = $rep->body();
            if (!str_contains($texte, "BEGIN:VCALENDAR")) {
                throw new \RuntimeException("Ce lien ne renvoie pas un calendrier (.ics).");
            }
            return static::importerTexte($cal, $texte);
        } catch (Throwable $th) {
            DB::table("airbnb_calendriers")->where("id", $cal->id)->update([
                "derniere_sync_a" => now(), "dernier_statut" => "erreur",
                "derniere_erreur" => mb_substr($th->getMessage(), 0, 500), "updated_at" => now(),
            ]);
            Log::warning("Synchronisation Airbnb du bien {$cal->realestate_id} : " . $th->getMessage());
            return 0;
        }
    }

    /** Enregistre les sejours d'un calendrier iCal deja lu. */
    public static function importerTexte(object $cal, string $texte): int
    {
        $evenements = static::lire($texte);
        $limite = today()->subDays(90)->toDateString();
        $gardes = [];

        DB::transaction(function () use ($cal, $evenements, $limite, &$gardes) {
            foreach ($evenements as $ev) {
                if ($ev["au"] < $limite) {
                    continue;
                }
                DB::table("airbnb_sejours")->updateOrInsert(
                    ["realestate_id" => $cal->realestate_id, "uid" => $ev["uid"]],
                    [
                        "du" => $ev["du"], "au" => $ev["au"], "type" => $ev["type"],
                        "resume" => mb_substr($ev["resume"], 0, 255), "description" => $ev["description"],
                        "lien" => $ev["lien"] ? mb_substr($ev["lien"], 0, 500) : null,
                        "updated_at" => now(), "created_at" => now(),
                    ]
                );
                $gardes[] = $ev["uid"];
            }
            // Ce qui a disparu d'Airbnb (annulation, deblocage) disparait ici.
            DB::table("airbnb_sejours")->where("realestate_id", $cal->realestate_id)
                ->when($gardes, fn($q) => $q->whereNotIn("uid", $gardes))
                ->delete();
            DB::table("airbnb_calendriers")->where("id", $cal->id)->update([
                "derniere_sync_a" => now(), "dernier_statut" => "ok", "derniere_erreur" => null, "updated_at" => now(),
            ]);
        });

        return count($gardes);
    }

    /** Les evenements d'un texte iCal : uid, du, au (exclu), type, resume, description, lien. */
    public static function lire(string $texte): array
    {
        // Les lignes longues sont repliees : une ligne qui commence par un espace continue la precedente.
        $texte = preg_replace("/\r?\n[ \t]/", "", str_replace("\r\n", "\n", $texte));
        $evenements = [];
        foreach (preg_split("/BEGIN:VEVENT/", $texte) as $i => $bloc) {
            if ($i === 0 || !str_contains($bloc, "END:VEVENT")) {
                continue;
            }
            $bloc = strstr($bloc, "END:VEVENT", true);
            $champ = function (string $nom) use ($bloc): ?string {
                return preg_match('/^' . $nom . '(?:;[^:\n]*)?:(.*)$/m', $bloc, $m) ? trim($m[1]) : null;
            };
            $date = function (?string $v): ?string {
                if (!$v || !preg_match('/^(\d{4})(\d{2})(\d{2})/', $v, $m)) return null;
                return "{$m[1]}-{$m[2]}-{$m[3]}";
            };
            $du = $date($champ("DTSTART"));
            $au = $date($champ("DTEND")) ?? ($du ? Carbon::parse($du)->addDay()->toDateString() : null);
            if (!$du || !$au || $au <= $du) {
                continue;
            }
            $resume = str_replace(["\\,", "\\;", "\\n"], [",", ";", " "], (string) $champ("SUMMARY"));
            $description = str_replace(["\\,", "\\;", "\\n"], [",", ";", "\n"], (string) $champ("DESCRIPTION"));
            $lien = preg_match('~https?://\S+~', $description, $m) ? rtrim($m[0], ".,)") : null;
            $bloque = preg_match('/not available|unavailable|blocked|indisponible|bloqu/i', $resume);
            $evenements[] = [
                "uid"         => $champ("UID") ?: md5($du . $au . $resume),
                "du"          => $du,
                "au"          => $au,
                "type"        => $bloque ? "bloque" : "reservation",
                "resume"      => $resume !== "" ? $resume : "Airbnb",
                "description" => $description !== "" ? $description : null,
                "lien"        => $lien,
            ];
        }
        return $evenements;
    }

    /** Un sejour Airbnb qui occupe au moins une des nuits du..au (au exclu). */
    public static function conflit(int $bienId, string $du, string $au, ?int $ignorer = null): ?object
    {
        if (!Schema::hasTable("airbnb_sejours")) {
            return null;
        }
        return DB::table("airbnb_sejours")->where("realestate_id", $bienId)
            ->where("du", "<", $au)->where("au", ">", $du)
            // Seule une reservation faite sur Airbnb empeche de reserver ici ;
            // une date simplement bloquee sur Airbnb reste reservable.
            ->where("type", "reservation")
            ->whereNull("booking_id")
            ->when($ignorer, fn($q) => $q->where("id", "!=", $ignorer))
            ->orderBy("du")->first();
    }

    /** Ce qu'Airbnb donne d'une reservation : code HM..., 4 derniers chiffres du telephone. */
    public static function details(object $s): array
    {
        $texte = (string) $s->description . " " . (string) $s->lien . " " . (string) $s->resume;
        $code = preg_match('~/details/([A-Z0-9]{6,})~', $texte, $m) || preg_match('~\b(HM[A-Z0-9]{6,})\b~', $texte, $m) ? $m[1] : null;
        $tel = preg_match('~(?:Last 4 Digits|4 derniers chiffres)[^0-9]*([0-9]{4})~i', $texte, $m) ? $m[1] : null;
        return [
            "id" => $s->id, "bienId" => $s->realestate_id, "du" => $s->du, "au" => $s->au,
            "nuits" => (int) round(Carbon::parse($s->du)->diffInDays(Carbon::parse($s->au))),
            "type" => $s->type, "resume" => $s->resume, "lien" => $s->lien,
            "code" => $code, "telephone4" => $tel, "bookingId" => $s->booking_id ?? null,
        ];
    }

    public static function messageConflit(object $s): string
    {
        return ($s->type === "bloque" ? "Ces dates sont bloquées sur Airbnb" : "Ces dates sont réservées sur Airbnb")
            . " (du " . Carbon::parse($s->du)->format("d/m/Y") . " au " . Carbon::parse($s->au)->format("d/m/Y") . ").";
    }

    /** Le calendrier de l'application pour un bien, au format iCal, sans nom de client. */
    public static function exporter(object $cal): string
    {
        $bienId = $cal->realestate_id;
        $depuis = today()->subDays(30)->toDateString();
        $ev = [];

        $reservations = DB::table("bookings")
            ->join("booking_statuses", "booking_statuses.id", "=", "bookings.status_id")
            ->where("bookings.realestate_id", $bienId)
            ->whereNull("bookings.deleted_at")
            ->where("booking_statuses.code", "<>", "rejected")
            ->where("bookings.checkout", ">=", $depuis)
            ->whereNull("bookings.airbnb_uid")
            ->get(["bookings.id", "bookings.checkin", "bookings.checkout"]);
        foreach ($reservations as $b) {
            $ev[] = ["uid" => "reservation-{$b->id}", "du" => substr($b->checkin, 0, 10), "au" => substr($b->checkout, 0, 10), "resume" => "Réservé"];
        }

        $blocages = DB::table("blocages_biens")->where("realestate_id", $bienId)->where("date_fin", ">=", $depuis)->get();
        foreach ($blocages as $b) {
            $ev[] = ["uid" => "blocage-{$b->id}", "du" => substr($b->date_debut, 0, 10),
                "au" => Carbon::parse($b->date_fin)->addDay()->toDateString(), "resume" => "Indisponible"];
        }

        if (Schema::hasTable("baux")) {
            $baux = DB::table("baux")->where("realestate_id", $bienId)->whereNull("deleted_at")->where("statut", "actif")
                ->where("date_fin", ">=", $depuis)->get();
            foreach ($baux as $b) {
                $ev[] = ["uid" => "bail-{$b->id}", "du" => substr($b->date_debut, 0, 10),
                    "au" => Carbon::parse($b->date_fin)->addDay()->toDateString(), "resume" => "Loué"];
            }
        }

        $hote = parse_url((string) config("app.url"), PHP_URL_HOST) ?: "agence";
        $horodatage = now()->utc()->format("Ymd\THis\Z");
        $lignes = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//" . $hote . "//Calendrier//FR", "CALSCALE:GREGORIAN", "METHOD:PUBLISH"];
        foreach ($ev as $e) {
            if ($e["au"] <= $e["du"]) continue;
            $lignes[] = "BEGIN:VEVENT";
            $lignes[] = "UID:" . $e["uid"] . "@" . $hote;
            $lignes[] = "DTSTAMP:" . $horodatage;
            $lignes[] = "DTSTART;VALUE=DATE:" . str_replace("-", "", $e["du"]);
            $lignes[] = "DTEND;VALUE=DATE:" . str_replace("-", "", $e["au"]);
            $lignes[] = "SUMMARY:" . $e["resume"];
            $lignes[] = "END:VEVENT";
        }
        $lignes[] = "END:VCALENDAR";

        DB::table("airbnb_calendriers")->where("id", $cal->id)->update(["derniere_lecture_export_a" => now()]);
        return implode("\r\n", $lignes) . "\r\n";
    }

    public static function etat(int $bienId): array
    {
        $cal = static::pour($bienId);
        $sejours = DB::table("airbnb_sejours")->where("realestate_id", $bienId)
            ->where("au", ">=", today()->toDateString())->orderBy("du")->limit(20)->get();
        return [
            "urlImport"      => $cal->url_import,
            "lienExport"     => static::lienExport($cal),
            "derniereSyncA"  => $cal->derniere_sync_a ? Carbon::parse($cal->derniere_sync_a)->toISOString() : null,
            "statut"         => $cal->dernier_statut,
            "erreur"         => $cal->derniere_erreur,
            "derniereLectureAirbnbA" => $cal->derniere_lecture_export_a ? Carbon::parse($cal->derniere_lecture_export_a)->toISOString() : null,
            "sejoursAVenir"  => $sejours->map(fn($s) => static::details($s))->values(),
        ];
    }
}
