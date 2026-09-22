<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\FeatureResource;
use App\Models\Feature;
use App\utils\JsonResponses;
use Illuminate\Http\Request;

class FeaturesController extends Controller
{

    use JsonResponses;

    public function index(Request $request)
    {
        $features = Feature::all();
        $data = FeatureResource::collection($features);
        return $this->jsonResponse(true, self::SUCCESS, 200, $data);
    }
}
