<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Dossier extends Model
{
    protected $table = "dossiers";

    protected $fillable = ["nom", "description", "type_code", "ordre", "created_by"];

    public function realestates()
    {
        return $this->hasMany(Realstate::class, "dossier_id");
    }

    /** Agents autorises sur ce dossier. */
    public function managers()
    {
        return $this->belongsToMany(Manager::class, "dossier_manager");
    }

    public function auteur()
    {
        return $this->belongsTo(Manager::class, "created_by");
    }
}
