<?php

namespace App\Services;

use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Throwable;
use WasenderApi\WasenderClient;

/**
 * La session Wasender des campagnes : un numero a part, pour que les envois
 * en masse ne touchent pas le numero des reservations. Sans reglage, les
 * campagnes partent du numero principal.
 */
class WhatsappCampagnes
{
    public const CLE = "wasender_campagnes_cle";
    public const INFOS = "wasender_campagnes_infos";

    public static function cle(): ?string
    {
        try {
            $v = DB::table("reglages_agence")->where("cle", static::CLE)->value("valeur");
            return $v ? Crypt::decryptString($v) : null;
        } catch (Throwable $e) {
            return null;
        }
    }

    public static function client(): WasenderClient
    {
        return new WasenderClient(static::cle() ?: config("services.whatsapp.wasender_key"));
    }

    public static function masquer(?string $cle): ?string
    {
        return $cle ? substr($cle, 0, 4) . "…" . substr($cle, -4) : null;
    }

    /** Ce que la session dit d'elle-meme (numero, nom) ; aucun message n'est envoye. */
    public static function lire(string $cle): array
    {
        $r = (new WasenderClient($cle))->getSessionUserInfo();
        $d = $r["data"] ?? $r;
        $tel = $d["phone_number"] ?? $d["phone"] ?? $d["id"] ?? ($d["user"]["id"] ?? null);
        if (is_string($tel)) $tel = preg_replace('/[:@].*$/', "", $tel);
        return ["numero" => $tel ? (string) $tel : null, "nom" => $d["name"] ?? $d["pushname"] ?? ($d["user"]["name"] ?? null)];
    }

    public static function etat(): array
    {
        $cle = static::cle();
        $infos = json_decode((string) DB::table("reglages_agence")->where("cle", static::INFOS)->value("valeur"), true) ?: [];
        return [
            "dedie" => (bool) $cle,
            "cle" => static::masquer($cle),
            "numero" => $cle ? ($infos["numero"] ?? null) : null,
            "nom" => $cle ? ($infos["nom"] ?? null) : null,
            "principal" => static::masquer(config("services.whatsapp.wasender_key")),
        ];
    }

    public static function enregistrer(?string $cle, array $infos = []): void
    {
        foreach ([static::CLE => $cle ? Crypt::encryptString($cle) : null, static::INFOS => $cle ? json_encode($infos) : null] as $k => $v) {
            if ($v === null) {
                DB::table("reglages_agence")->where("cle", $k)->delete();
            } else {
                DB::table("reglages_agence")->updateOrInsert(["cle" => $k], ["valeur" => $v, "updated_at" => now(), "created_at" => now()]);
            }
        }
    }
}
