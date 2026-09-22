<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class ProgramedCharge extends Model
{
    use SoftDeletes;
    protected $fillable = [
        "nom",
        "description",
        "amount",
        "type",
        "month",
        "day",
        "day_name",
        "realestate_id"
    ];



    public function realestate()
    {
        return $this->belongsTo(Realstate::class, "realestate_id");
    }
}
