<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Rappel extends Model
{
    protected $table = "rappels";

    /** Rappels cales sur une date : le planificateur les surveille. */
    public const MOMENT_ARRIVEE = "checkin";
    public const MOMENT_DEPART  = "checkout";

    /**
     * Declenche par le constat du depart, pas par l'horloge.
     *
     * Les dates d'arrivee et de sortie sont des jours, sans heure : un
     * decalage calcule dessus tombe au milieu de la nuit. Le geste de
     * l'agent, lui, arrive au bon moment.
     */
    public const MOMENT_CLIC = "depart";

    protected $fillable = [
        "code", "libelle", "moment", "decalage_heures",
        "vers_client", "vers_agent", "modele_client", "modele_agent",
        "actif", "ordre",
    ];

    protected $casts = [
        "vers_client"     => "boolean",
        "vers_agent"      => "boolean",
        "actif"           => "boolean",
        "decalage_heures" => "integer",
    ];

    public function envois()
    {
        return $this->hasMany(RappelEnvoye::class, "rappel_id");
    }

    /** "3 jours avant l'arrivée", "3 heures après le départ"... */
    public function delaiLisible(): string
    {
        if ($this->moment === self::MOMENT_CLIC) {
            return "quand le d\u{E9}part est confirm\u{E9}";
        }

        $h = abs($this->decalage_heures);
        $avant = $this->decalage_heures < 0;
        $reference = $this->moment === "checkin" ? "l'arrivée" : "le départ";

        if ($h === 0) {
            return "le jour de " . ($this->moment === "checkin" ? "l'arrivée" : "du départ");
        }

        $duree = $h % 24 === 0
            ? intdiv($h, 24) . " jour" . (intdiv($h, 24) > 1 ? "s" : "")
            : $h . " heure" . ($h > 1 ? "s" : "");

        return $duree . " " . ($avant ? "avant " : "après ") . $reference;
    }
}
