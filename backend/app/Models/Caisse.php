<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Un detenteur d'argent.
 *
 * Le solde n'est pas une colonne : il se calcule a partir des
 * mouvements. Une valeur stockee pourrait etre corrigee sans laisser de
 * trace, et cesserait donc d'etre une preuve.
 */
class Caisse extends Model
{
    protected $table = "caisses";

    protected $fillable = ["nom", "type", "manager_id", "actif"];

    protected $casts = ["actif" => "boolean"];

    public function mouvements()
    {
        return $this->hasMany(MouvementCaisse::class, "caisse_id");
    }

    public function manager()
    {
        return $this->belongsTo(Manager::class, "manager_id");
    }

    public function sessions()
    {
        return $this->hasMany(SessionCaisse::class, "caisse_id");
    }

    /** La caisse actuellement ouverte, s'il y en a une. */
    public function sessionCourante(): ?SessionCaisse
    {
        return $this->sessions()->whereNull("close_le")
            ->orderByDesc("id")->first();
    }

    /**
     * Le solde de la caisse en cours.
     *
     * Pas un cumul depuis toujours : ce que l'agent doit avoir sur lui
     * maintenant, dans la caisse qu'il a ouverte.
     */
    public function solde(): float
    {
        return $this->sessionCourante()?->solde() ?? 0.0;
    }

    /** Vrai lorsqu'une caisse est ouverte en ce moment. */
    public function ouverte(): bool
    {
        return $this->sessionCourante() !== null;
    }

    /** Le montant compte a la derniere cloture, a reporter. */
    public function dernierMontantCompte(): float
    {
        $derniere = CloturageCaisse::where("caisse_id", $this->id)
            ->orderByDesc("cloture_le")->first();

        return round((float) ($derniere?->montant_compte ?? 0), 2);
    }
}
