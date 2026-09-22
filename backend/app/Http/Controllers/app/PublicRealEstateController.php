<?php

namespace App\Http\Controllers\app;

use App\Filters\RealestateFilter;
use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\RealestatePaginateResource;
use App\Http\Resources\AppResources\RealestateResource;
use App\Http\Resources\PaginationResource;
use App\Models\Realstate;
use App\Models\RealstateCategory;
use App\Models\RealstateEtat;
use App\Models\RealstateReviewStatus;
use App\Models\RealstateStatus;
use App\Models\TypeTransaction;
use App\Models\UserType;
use App\utils\JsonResponses;
use Illuminate\Container\Attributes\Auth;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class PublicRealEstateController extends Controller
{
    use JsonResponses;


    public function index(Request $request)
    {
        $data = Realstate::filter(new RealestateFilter($request))
            ->with(["city.region.country", "category", "type", "reviewStatus", "status", "etat", "features", "host"])
            ->whereHas("status", function ($query) {
                $query->where("code", "=", "active");
            })
            ->whereHas("reviewStatus", function ($query) {
                $query->where("code", "=", "legal");
            })
            ->when($request->filled("checkin") && $request->filled("checkout"), function ($query) use ($request) {
                $query->whereDoesntHave("bookings", function ($query) use ($request) {
                    $query->where("checkin", "<=", $request->input("checkout"))
                        ->where("checkout", ">=", $request->input("checkin"))
                        ->whereHas("status", function ($query) {
                            $query->where("code", "=", "payed");
                        });
                });
            })
            ->orderByRaw("rate * nb_raters DESC")
            ->paginate($request->input("perPage", 20), ['*'], "realestate", $request->input("page", 1));

        //fetch favorites if authenticated
        $user = auth("sanctum")->user();

        $favorites = $user ? $user->favorites()->pluck("realstates.id")->toArray() : [];

        $realestateResources = $data->getCollection()
            ->map(function ($realestate) use ($favorites) {
                $isFavorite = in_array($realestate->id, $favorites);
                return (new RealestateResource($realestate))->setIsFavorite($isFavorite);
            });
        $data->setCollection($realestateResources);



        $response = new PaginationResource(
            RealestateResource::collection($data)
        );

        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }

    public function show(Request $request, $id)
    {
        $user = auth("sanctum")->user();
        $realestate = Realstate::with(["city.region.country", "bookings", "category", "type", "reviewStatus", "status", "etat", "features", "host"])
            ->where("id", "=", $id)
            ->whereHas("status", function ($query) {
                $query->where("code", "=", "active");
            })
            ->whereHas("reviewStatus", function ($query) {
                $query->where("code", "=", "legal");
            })->first();
        if (!$realestate) {
            return $this->jsonResponse(true, self::NOT_FOUND, 404, null);
        }
        //check if reservable
        $isReservable = true;
        if ($user && $user->type->code == "host") {
            $hr = $user->realestates()->where("id", "=", $id)->first();
            if ($hr) {
                $isReservable = false;
            }
        }
        //check if favorite
        $isFavorite = false;
        if ($user) {
            $fr = $user->favorites()->where("realstates.id", "=", $id)->first();
            if ($fr) {
                $isFavorite = true;
            }
        }
        //get booking dates
        $reservedDates = $realestate->bookings()
            ->where("checkout", ">=", now())
            ->whereHas("status", function ($query) {
                $query->where("code", "=", "payed");
            })->get()->map(function ($item) {
                return [
                    "checkin" => $item->checkin,
                    "checkout" => $item->checkout,
                ];
            });



        $response = (new RealestateResource($realestate))
            ->setIsReservable($isReservable)
            ->setIsFavorite($isFavorite)
            ->setReservedDates($reservedDates);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }
}
