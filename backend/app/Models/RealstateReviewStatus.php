<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RealstateReviewStatus extends Model
{
    protected $table = "realstate_review_status";

    protected $fillable = [
        "status",
        "code"
    ];
}
