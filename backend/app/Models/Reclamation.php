<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;

class Reclamation extends Model implements HasMedia
{
    use InteractsWithMedia, SoftDeletes;

    protected $fillable = [
        'note',
        'status',
        'realestate_id',
        'manager_id',
    ];
    protected $casts = [
        "realestate_id" => "int"
    ];

    public function registerMediaCollections(): void
    {
        $this->addMediaCollection('images');
    }

    public function manager()
    {
        return $this->belongsTo(Manager::class, 'manager_id');
    }

    public function realestate()
    {
        return $this->belongsTo(Realstate::class, 'realestate_id');
    }
}
