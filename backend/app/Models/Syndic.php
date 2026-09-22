<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/** Le syndic d'un immeuble : il recoit le contrat public des sejours. */
class Syndic extends Model
{
    use SoftDeletes;

    protected $fillable = ["nom", "telephone", "actif", "notes", "created_by"];

    protected $casts = ["actif" => "boolean"];

    /** Un bien peut dependre de plusieurs syndics. */
    public function biens()
    {
        return $this->belongsToMany(Realstate::class, "realestate_syndic", "syndic_id", "realestate_id")->withTimestamps();
    }
}
