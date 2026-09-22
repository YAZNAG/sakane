<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RappelEnvoye extends Model
{
    protected $table = "rappels_envoyes";

    protected $fillable = [
        "booking_id", "rappel_id", "destinataire", "telephone",
        "statut", "erreur", "envoye_a", "tentatives",
    ];

    protected $casts = ["envoye_a" => "datetime"];

    public function rappel()
    {
        return $this->belongsTo(Rappel::class, "rappel_id");
    }

    public function booking()
    {
        return $this->belongsTo(Booking::class, "booking_id");
    }
}
