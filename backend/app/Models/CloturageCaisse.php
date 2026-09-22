<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Un comptage de caisse, a un instant donne.
 *
 * L'ecart est fige a la cloture : recalcule plus tard, il changerait
 * au gre des mouvements suivants et ne prouverait plus rien.
 */
class CloturageCaisse extends Model
{
    protected $table = "cloturages_caisse";

    protected $fillable = [
        "caisse_id", "session_id", "solde_theorique", "montant_compte", "ecart",
        "debut_periode", "montant_depart",
        "total_entrees", "total_sorties", "total_remis",
        "cloture_par", "cloture_le", "commentaire",
    ];

    protected $casts = [
        "solde_theorique" => "decimal:2",
        "montant_depart"  => "decimal:2",
        "total_entrees"   => "decimal:2",
        "total_sorties"   => "decimal:2",
        "total_remis"     => "decimal:2",
        "debut_periode"   => "datetime",
        "montant_compte"  => "decimal:2",
        "ecart"           => "decimal:2",
        "cloture_le"      => "datetime",
    ];

    public function caisse()
    {
        return $this->belongsTo(Caisse::class, "caisse_id");
    }

    public function auteur()
    {
        return $this->belongsTo(Manager::class, "cloture_par");
    }

    public function juste(): bool
    {
        return abs((float) $this->ecart) < 0.01;
    }
}
