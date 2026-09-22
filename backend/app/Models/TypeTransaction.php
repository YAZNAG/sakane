<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class TypeTransaction extends Model
{

    protected $table = "type_transactions";
    protected $fillable = [
        "type",
        "code"
    ];
}
