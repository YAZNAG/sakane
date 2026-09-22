<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;

class Contract extends Model implements HasMedia
{
    use InteractsWithMedia;
    protected $fillable = [
        "note",
        "owner_id",
        "client_id",
        "signed_date",
        "expiration_date",
        "realestate_id"
    ];

    public function registerMediaCollections(): void
    {
        $this->addMediaCollection("documents");
    }



    public function client()
    {
        return $this->belongsTo(User::class, "client_id");
    }
    public function realestate()
    {
        return $this->belongsTo(Realstate::class, "realestate_id");
    }
    public function owner()
    {
        return $this->belongsTo(Owner::class, "owner_id");
    }
}
