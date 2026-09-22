<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\CityResource;
use App\Models\City;
use App\utils\JsonResponses;
use Illuminate\Http\Request;

class CityController extends Controller
{
    use JsonResponses;


    public function index(Request $request)
    {
        $cities = null;
        if ($request->has("region")) {
            $cities = City::where("region_id", "=", $request->query("region"))->get();
        } else {
            $cities = City::all();
        }
        $data = CityResource::collection($cities);
        return $this->jsonResponse(true, self::SUCCESS, 200, $data);
    }
}
