<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Owner extends Model
{
    use SoftDeletes;
    protected $fillable = [
        "name",
        "email",
        "tel",
        "address"
    ];


    /** Les contrats signes avec ce proprietaire. */
    public function contrats()
    {
        return $this->hasMany(ContratProprietaire::class, "owner_id")->orderByDesc("created_at");
    }

    public function realestates(){
        return $this->hasMany(Realstate::class,"owner_id");
    }


}
