<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\RegionResource;
use App\Models\Region;
use App\utils\JsonResponses;
use Illuminate\Http\Request;

class RegionController extends Controller
{
    use JsonResponses;


    public function index(Request $request)
    {
        $regions = Region::all();
        $data = RegionResource::collection($regions);
        return $this->jsonResponse(true, self::SUCCESS, 200, $data);
    }
}
