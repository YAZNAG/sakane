<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;

class Charge extends Model implements HasMedia
{
    use InteractsWithMedia,SoftDeletes;

    protected $fillable = [
        "amount",
        "realestate_id",
        "manager_id",
        "status",
        "type",
        "description",
        "nom",
        "cancelled_at",
        "cancelled_by",
        "montant_rembourse",
        "motif_annulation",
    ];

    protected $casts = [
        "amount"            => "double",
        "montant_rembourse" => "double",
        "cancelled_at"      => "datetime",
    ];


    public function registerMediaCollections(): void
    {
        $this->addMediaCollection('document')->singleFile();
    }

    public function realestate()
    {
        return $this->belongsTo(Realstate::class, "realestate_id");
    }

    /** Celui dont la caisse porte cette depense. */
    public function manager()
    {
        return $this->belongsTo(Manager::class, "manager_id");
    }
}
