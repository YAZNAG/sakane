<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/** Plusieurs syndics par bien, preferences de l'accueil, reception WhatsApp par message. */
return new class extends Migration
{
    private const GROUPES = [
        "reservations" => ["reservation-ajoutee", "reservation-prolongee", "reservation-raccourcie", "reservation-prix-modifie"],
        "nettoyage"    => ["nettoyage-a-faire", "nettoyage-commence", "nettoyage-termine"],
        "charges"      => ["charge-ajoutee", "charge-traitee", "charge-programmee"],
        "reclamations" => ["reclamation-ajoutee", "reclamation-resolue"],
    ];

    public function up(): void
    {
        if (!Schema::hasTable("realestate_syndic")) {
            Schema::create("realestate_syndic", function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger("realestate_id")->index();
                $t->unsignedBigInteger("syndic_id")->index();
                $t->timestamps();
                $t->unique(["realestate_id", "syndic_id"]);
            });
            foreach (DB::table("realstates")->whereNotNull("syndic_id")->get(["id", "syndic_id"]) as $b) {
                DB::table("realestate_syndic")->insertOrIgnore(["realestate_id" => $b->id, "syndic_id" => $b->syndic_id, "created_at" => now(), "updated_at" => now()]);
            }
        }
        // Les anciens reglages coupaient un groupe entier : chaque message du groupe est coupe.
        foreach (DB::table("managers")->whereNotNull("whatsapp_types_coupes")->get(["id", "whatsapp_types_coupes"]) as $m) {
            $coupes = json_decode((string) $m->whatsapp_types_coupes, true) ?: [];
            $fins = [];
            foreach ($coupes as $c) {
                foreach (self::GROUPES[$c] ?? [$c] as $f) $fins[] = $f;
            }
            DB::table("managers")->where("id", $m->id)->update(["whatsapp_types_coupes" => $fins ? json_encode(array_values(array_unique($fins))) : null]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists("realestate_syndic");
    }
};
