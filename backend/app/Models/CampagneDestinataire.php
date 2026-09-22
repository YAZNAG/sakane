<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CampagneDestinataire extends Model
{
    protected $table = "campagne_destinataires";

    protected $fillable = [
        "campagne_id",
        "client_id",
        "ordre",
        "telephone",
        "message_final",
        "statut",
        "erreur",
        "envoye_a",
        "tentatives",
    ];

    protected $casts = [
        "envoye_a" => "datetime",
    ];

    public function campagne()
    {
        return $this->belongsTo(Campagne::class, "campagne_id");
    }

    public function client()
    {
        return $this->belongsTo(User::class, "client_id");
    }
}
