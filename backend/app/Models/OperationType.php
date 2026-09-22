<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OperationType extends Model
{
    protected $table = "operation_types";
    protected $fillable = [
        "type",
        "code"
    ];
}
