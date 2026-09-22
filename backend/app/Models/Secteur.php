<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Secteur extends Model
{
    protected $table = "secteurs";

    protected $fillable = ["nom", "city_id"];

    public function city()
    {
        return $this->belongsTo(City::class, "city_id");
    }

    public function realestates()
    {
        return $this->hasMany(Realstate::class, "secteur_id");
    }

    /**
     * Retrouve un secteur par son nom dans une ville, sans tenir compte
     * de la casse ni des espaces superflus, et le cree s'il n'existe pas.
     */
    public static function trouverOuCreer(string $nom, $cityId = null): ?self
    {
        $nom = trim(preg_replace('/\s+/u', ' ', $nom));
        if ($nom === '') {
            return null;
        }

        $existant = static::when($cityId, fn($q) => $q->where('city_id', $cityId))
            ->whereRaw('LOWER(nom) = ?', [mb_strtolower($nom)])
            ->first();

        if ($existant) {
            return $existant;
        }

        return static::create(["nom" => $nom, "city_id" => $cityId]);
    }
}
