<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Une caisse ouverte, de son fond de depart a sa cloture.
 */
class SessionCaisse extends Model
{
    protected $table = "sessions_caisse";

    protected $fillable = [
        "caisse_id", "numero", "montant_ouverture", "reporte",
        "ouverte_le", "ouverte_par", "close_le", "cloturage_id",
    ];

    protected $casts = [
        "montant_ouverture" => "decimal:2",
        "reporte"           => "boolean",
        "ouverte_le"        => "datetime",
        "close_le"          => "datetime",
    ];

    public function caisse()
    {
        return $this->belongsTo(Caisse::class, "caisse_id");
    }

    public function mouvements()
    {
        return $this->hasMany(MouvementCaisse::class, "session_id");
    }

    public function cloturage()
    {
        return $this->belongsTo(CloturageCaisse::class, "cloturage_id");
    }

    public function ouverte(): bool
    {
        return $this->close_le === null;
    }

    /** Le solde de cette caisse-la, et d'elle seule. */
    public function solde(): float
    {
        $entrees = (float) $this->mouvements()->where("sens", "entree")->sum("montant");
        $sorties = (float) $this->mouvements()->where("sens", "sortie")->sum("montant");

        return round($entrees - $sorties, 2);
    }
}
