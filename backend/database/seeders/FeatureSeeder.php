<?php

namespace Database\Seeders;

use App\Models\Feature;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class FeatureSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $features = [
            [
                "name" => "Jardin",
                "description" => "Jardin extérieur magnifique",
                "icon" => "icon-garden"
            ],
            [
                "name" => "Terrasse",
                "description" => "Terrasse extérieure pour la détente",
                "icon" => "icon-terrace"
            ],
            [
                "name" => "Garage",
                "description" => "Espace sécurisé pour garer des véhicules",
                "icon" => "icon-garage"
            ],
            [
                "name" => "Ascenseur",
                "description" => "Ascenseur pour un accès facile",
                "icon" => "icon-elevator"
            ],
            [
                "name" => "Vue sur mer",
                "description" => "Vue imprenable sur la mer depuis la propriété",
                "icon" => "icon-seaViews"
            ],
            [
                "name" => "Vue sur les montagnes",
                "description" => "Vue imprenable sur les montagnes",
                "icon" => "icon-mountainsViews"
            ],
            [
                "name" => "Piscine",
                "description" => "Piscine privée pour la détente",
                "icon" => "icon-pool"
            ],
            [
                "name" => "Concierge",
                "description" => "Service de concierge sur place",
                "icon" => "icon-doorman"
            ],
            [
                "name" => "Chambre rangement",
                "description" => "Chambre de rangement pour un espace supplémentaire",
                "icon" => "icon-storageRoom"
            ],
            [
                "name" => "Meublé",
                "description" => "Entièrement meublé pour le confort",
                "icon" => "icon-furnished"
            ],
            [
                "name" => "Façade extérieure",
                "description" => "Façade extérieure élégante",
                "icon" => "icon-exteriorFacade"
            ],
            [
                "name" => "Salon Marocain",
                "description" => "Salon de style traditionnel marocain",
                "icon" => "icon-moroccanLounge"
            ],
            [
                "name" => "Salon européen",
                "description" => "Salon de style européen classique",
                "icon" => "icon-europeanLounge"
            ],
            [
                "name" => "Antenne parabolique",
                "description" => "Antenne pour la réception de la télévision par satellite",
                "icon" => "icon-satellite"
            ],
            [
                "name" => "Cheminée",
                "description" => "Cheminée intérieure chaleureuse",
                "icon" => "icon-fireplace"
            ],
            [
                "name" => "Climatisation",
                "description" => "Système de climatisation pour le refroidissement",
                "icon" => "icon-airConditioning"
            ],
            [
                "name" => "Chauffage central",
                "description" => "Système de chauffage central pour la chaleur de la maison",
                "icon" => "icon-heating"
            ],
            [
                "name" => "Sécurité",
                "description" => "Caractéristiques de sécurité pour protéger la propriété",
                "icon" => "icon-security"
            ],
            [
                "name" => "Double vitrage",
                "description" => "Fenêtres à double vitrage écoénergétiques",
                "icon" => "icon-doubleGlazing"
            ],
            [
                "name" => "Porte blindée",
                "description" => "Porte renforcée de haute sécurité pour la protection",
                "icon" => "icon-reinforcedDoor"
            ],
            [
                "name" => "Cuisine équipée",
                "description" => "Cuisine entièrement équipée pour la commodité de la cuisine",
                "icon" => "icon-fullKitchen"
            ],
            [
                "name" => "Réfrigérateur",
                "description" => "Réfrigérateur pour la préservation des aliments",
                "icon" => "icon-fridge"
            ],
            [
                "name" => "Four",
                "description" => "Four pour cuire et cuisiner",
                "icon" => "icon-oven"
            ],
            [
                "name" => "Machine à laver",
                "description" => "Machine à laver pour la lessive",
                "icon" => "icon-washer"
            ],
            [
                "name" => "Micro-ondes",
                "description" => "Micro-ondes pour les repas rapides",
                "icon" => "icon-microwave"
            ]
        ];

        foreach ($features as $feature) {
            Feature::create($feature);
        }
    }
}
