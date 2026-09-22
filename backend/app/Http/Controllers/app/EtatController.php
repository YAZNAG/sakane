<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\EtatResource;
use App\Models\RealstateEtat;
use App\utils\JsonResponses;
use Illuminate\Http\Request;

class EtatController extends Controller
{
    use JsonResponses;


    public function index(Request $request)
    {
        $etats = RealstateEtat::all();
        $data = EtatResource::collection($etats);
        return $this->jsonResponse(true, self::SUCCESS, 200, $data);
    }
}
