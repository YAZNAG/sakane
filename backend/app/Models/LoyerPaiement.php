<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;

/** Un paiement de loyer ; annule, il reste visible avec sa contre-passation. */
class LoyerPaiement extends Model implements HasMedia
{
    use InteractsWithMedia;

    protected $table = "loyer_paiements";

    protected $guarded = ["id"];

    protected $casts = [
        "montant"              => "decimal:2",
        "paye_le"              => "date",
        "quittance_envoyee_le" => "datetime",
        "annule_le"            => "datetime",
    ];

    public const MODES = ["especes" => "Espèces", "virement" => "Virement", "cheque" => "Chèque"];

    public function registerMediaCollections(): void
    {
        $this->addMediaCollection("quittance")->singleFile();
    }

    public function loyer()
    {
        return $this->belongsTo(Loyer::class, "loyer_id");
    }

    public function bail()
    {
        return $this->belongsTo(Bail::class, "bail_id")->withTrashed();
    }

    public function manager()
    {
        return $this->belongsTo(Manager::class, "manager_id")->withTrashed();
    }
}
