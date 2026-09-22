<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class WhatsappMessageHistorique extends Model
{
    protected $table = "whatsapp_message_historique";

    protected $fillable = [
        "whatsapp_message_id",
        "contenu_avant",
        "contenu_apres",
        "manager_id",
    ];

    public function auteur()
    {
        return $this->belongsTo(Manager::class, "manager_id");
    }
}
