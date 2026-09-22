<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class TypeBooking extends Model
{
    protected $fillable = [
        "type",
        "code"
    ];
}
