<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;

class RealestateRapport extends Model implements HasMedia
{
    use InteractsWithMedia,SoftDeletes;


    protected $fillable = [
        "name",
        "description",
        "date",
        "realestate_id"
    ];
    public function registerMediaCollections(): void
    {
        $this->addMediaCollection('images');
    }
}
