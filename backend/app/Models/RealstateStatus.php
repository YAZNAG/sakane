<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RealstateStatus extends Model
{
    protected $table = "realstate_status";

    protected $fillable = [
        "status",
        "code"
    ];
}
