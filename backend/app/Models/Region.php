<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Region extends Model
{
    protected $fillable = [
        "name",
        "latitude",
        "longitude",
        "country_id"
    ];

    public function country()
    {
        return $this->belongsTo(Country::class);
    }
}
