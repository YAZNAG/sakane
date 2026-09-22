<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\RealestateResource;
use App\Http\Resources\PaginationResource;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class FavoritesController extends Controller
{
    use JsonResponses;


    public function index(Request $request)
    {
        $user = $request->user();
        $favorites = $user->favorites()
            ->whereHas("status", function ($query) {
                $query->where("code", "=", "active");
            })
            ->whereHas("reviewStatus", function ($query) {
                $query->where("code", "=", "legal");
            })->orderByPivot("created_at", "desc")
            ->paginate(
                $request->input("perPage", 20),
                ['*'],
                'favorites',
                $request->input("page", 1)
            );
        $realstateResources = $favorites->getCollection()->map(function ($realestate) {
            return (new RealestateResource($realestate))->setIsFavorite(true);
        });
        $favorites->setCollection($realstateResources);
        $response = new PaginationResource(RealestateResource::collection($favorites));
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }


    public function addRealestateToFavorites(Request $request)
    {
        $user = $request->user();
        $validator = Validator::make($request->all(), [
            "realestate" => ["required", "exists:realstates,id"]
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors);
        }
        $user->favorites()->attach($request->input("realestate"));
        return $this->jsonResponse(true, self::SUCCESS, 200, null);
    }

    public function removeRealestateFromFavorites(Request $request)
    {
        $user = $request->user();
        $validator = Validator::make($request->all(), [
            "realestate" => ["required", "exists:realstates,id"]
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors);
        }
        $user->favorites()->detach($request->input("realestate"));
        return $this->jsonResponse(true, self::SUCCESS, 200, null);
    }
}
