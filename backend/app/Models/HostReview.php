<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class HostReview extends Model
{

    protected $fillable = [
        "rate",
        "comment",
        "cleanliness",
        "observance_house_rules",
        "communication",
        "host_id",
    ];
    public function booking()
    {
        return $this->hasOne(Booking::class);
    }
    public function host()
    {
        return $this->belongsTo(User::class, "host_id");
    }
}
