<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;

/** Une echeance mensuelle d'un bail. */
class Loyer extends Model
{
    protected $table = "loyers";

    protected $guarded = ["id"];

    protected $casts = [
        "periode_debut" => "date",
        "periode_fin"   => "date",
        "echeance"      => "date",
        "montant"       => "decimal:2",
        "paye"          => "decimal:2",
    ];

    public function bail()
    {
        return $this->belongsTo(Bail::class, "bail_id")->withTrashed();
    }

    public function paiements()
    {
        return $this->hasMany(LoyerPaiement::class, "loyer_id")->orderBy("paye_le")->orderBy("id");
    }

    public function reste(): float
    {
        return round(max(0, (float) $this->montant - (float) $this->paye), 2);
    }

    /** paye, partiel, en_retard, a_payer (aujourd'hui) ou a_venir. */
    public function statut(): string
    {
        if ($this->reste() <= 0.009) {
            return "paye";
        }
        $aujourdhui = today();
        if ($this->echeance->lt($aujourdhui)) {
            return "en_retard";
        }
        if ((float) $this->paye > 0) {
            return "partiel";
        }
        return $this->echeance->isSameDay($aujourdhui) ? "a_payer" : "a_venir";
    }

    public function libelle(): string
    {
        return ucfirst(Carbon::parse($this->periode_debut)->locale("fr")->isoFormat("MMMM YYYY"));
    }

    /** Recalcule le montant paye a partir des paiements non annules. */
    public function recalculer(): void
    {
        $this->paye = round((float) $this->paiements()->whereNull("annule_le")->sum("montant"), 2);
        $this->save();
    }
}
