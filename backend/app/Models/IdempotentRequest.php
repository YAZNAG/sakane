<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class IdempotentRequest extends Model
{
    protected $table = "idempotent_requests";

    protected $fillable = [
        "cle",
        "methode",
        "chemin",
        "status_code",
        "reponse",
        "manager_id",
    ];
}
