<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\AppVersion;

class AppVersionController extends Controller
{
    /**
     * Retourne la version courante d'une application mobile.
     * Format identique a l'ancien service externe : reponse a la racine,
     * is_active en 0/1, dates parsables par DateTime.parse cote Flutter.
     */
    public function show(string $package)
    {
        $app = AppVersion::where('package_name', $package)->first();

        if (!$app) {
            return response()->json(['message' => 'application introuvable'], 404);
        }

        return response()->json([
            'id'           => $app->id,
            'version'      => $app->version,
            'package_name' => $app->package_name,
            'apk_url'      => $app->apk_url,
            'description'  => $app->description,
            'is_active'    => $app->is_active ? 1 : 0,
            'created_at'   => $app->created_at->format('Y-m-d H:i:s'),
            'updated_at'   => $app->updated_at->format('Y-m-d H:i:s'),
        ]);
    }
}
