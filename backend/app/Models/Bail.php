<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;

/** Un bail de location longue duree. */
class Bail extends Model implements HasMedia
{
    use InteractsWithMedia, SoftDeletes;

    protected $table = "baux";

    protected $guarded = ["id"];

    protected $casts = [
        "date_debut"       => "date",
        "date_fin"         => "date",
        "termine_le"       => "date",
        "loyer"            => "decimal:2",
        "charges"          => "decimal:2",
        "depot"            => "decimal:2",
        "depot_rendu"      => "decimal:2",
        "relances_actives" => "boolean",
        "colocataires"     => "array",
    ];

    public function registerMediaCollections(): void
    {
        $this->addMediaCollection("contrat")->singleFile();
        $this->addMediaCollection("etat_lieux");
        $this->addMediaCollection("cin");
    }

    public function bien()
    {
        return $this->belongsTo(Realstate::class, "realestate_id");
    }

    public function locataire()
    {
        return $this->belongsTo(User::class, "client_id")->withTrashed();
    }

    public function loyers()
    {
        return $this->hasMany(Loyer::class, "bail_id")->orderBy("periode_debut");
    }

    public function paiements()
    {
        return $this->hasMany(LoyerPaiement::class, "bail_id");
    }

    public function auteur()
    {
        return $this->belongsTo(Manager::class, "created_by");
    }

    public function montantMensuel(): float
    {
        return round((float) $this->loyer + (float) $this->charges, 2);
    }
}
