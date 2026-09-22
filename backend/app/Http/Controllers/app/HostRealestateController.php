<?php

namespace App\Http\Controllers\app;

use App\Filters\RealestateFilter;
use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\HostRealestateResource;
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
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class HostRealestateController extends Controller
{
    use JsonResponses;


    public function index(Request $request)
    {
        $user = $request->user();
        if ($user->type->code != "host") {
            return $this->jsonResponse(false, "not-host", 403, null);
        }
        $realestates = Realstate::where("host_id", "=", $user->id)
            ->with(["city.region.country", "category", "type", "reviewStatus", "status", "etat", "features", "host"])
            ->orderBy("created_at", "desc")
            ->paginate($request->input("perPage", 15), ['*'], "page", $request->input("page", 1));
        $response = new PaginationResource(HostRealestateResource::collection($realestates));
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }

    /**
     * Store a newly created resource in storage.
     */
    // public function store(Request $request)
    // {
    //     $user = $request->user();
    //     $type = UserType::where("id", "=", $user->type_id)->first();
    //     if ($type->code != "host") {
    //         return $this->jsonResponse(false, self::NO_ACCESS, 403, null);
    //     }
    //     $validator = Validator::make(
    //         $request->all(),
    //         [
    //             "title" => ["required", "string"],
    //             "description" => ["required", "string"],
    //             "price" => ["required", "numeric", "gt:0"],
    //             "surface" => ["required", "integer", "gt:0"],
    //             "address" => ["required", "string"],
    //             "dateConstruction" => ["sometimes", "date_format:Y-m-d"],
    //             "nbEtages" => ["sometimes", "integer"],
    //             "nbRooms" => ["sometimes", "integer"],
    //             "etage" => ["sometimes", "integer"],
    //             "nbBathrooms" => ["sometimes", "integer"],
    //             "latitude" => ["required", "numeric"],
    //             "longitude" => ["required", "numeric"],
    //             "tour360Url" => ["sometimes", "url:http,https"],
    //             "category" => ["required", "exists:realstate_categories,code"],
    //             "typeTransaction" => ["required", "exists:type_transactions,code"],
    //             "etat" => ["required", "exists:realstate_etats,code"],
    //             "city" => ["required", "exists:cities,id"],
    //             "features" => ["nullable", "array"],
    //             "features.*" => ["exists:features,id"],
    //             "images" => ["required", "min:2", "max:10"],
    //             "images.*" => ["image", "mimes:png,jpg,jpeg", "max:2048"]
    //         ]
    //     );
    //     if ($validator->fails()) {
    //         return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
    //     }
    //     //create realestate
    //     $data = $validator->validated();
    //     $data["date_construction"] = isset($data["dateConstruction"]) ? $data["dateConstruction"] : null;
    //     $data["nb_etage"] = isset($data["nbEtages"]) ? $data["nbEtages"] : null;
    //     $data["nb_rooms"] = isset($data["nbRooms"]) ? $data["nbRooms"] : null;
    //     $data["nb_bathroom"] = isset($data["nbBathrooms"]) ? $data["nbBathrooms"] : null;
    //     $data["tour_360_url"] = isset($data["tour360Url"]) ? $data["tour360Url"] : null;
    //     $data["category_id"] = RealstateCategory::where("code", "=", $data["category"])->first()->id;
    //     $data["transaction_id"] = TypeTransaction::where("code", "=", $data["typeTransaction"])->first()->id;
    //     $data["etat_id"] = RealstateEtat::where("code", "=", $data["etat"])->first()->id;
    //     $data["city_id"] = $data["city"];
    //     $data["review_status_id"] = RealstateReviewStatus::where("code", "=", "in-review")->first()->id;
    //     $data["status_id"] = RealstateStatus::where("code", "=", "pending")->first()->id;
    //     $data["host_id"] = $user->id;

    //     $realstate = Realstate::create($data);

    //     //add features to realestate
    //     $realstate->features()->attach($data["features"]);

    //     //add images
    //     $images = $request->file("images");
    //     for ($i = 0; $i < count($images); $i++) {
    //         $image = $images[$i];
    //         $ext = $image->getClientOriginalExtension();
    //         $fileName = ($i + 1) . "." . $ext;
    //         $realstate->addMedia($image)->usingFileName($fileName)->toMediaCollection("images");
    //     }
    //     //return realestate
    //     $response = new RealestateResource($realstate);
    //     return $this->jsonResponse(true, self::SUCCESS, 201, $response);
    // }

    public function store(Request $request)
    {
        $user = $request->user();
        $type = UserType::where("id", "=", $user->type_id)->first();
        if ($type->code != "host") {
            return $this->jsonResponse(false, self::NO_ACCESS, 403, null);
        }

        $validator = Validator::make(
            $request->all(),
            [
                "title" => ["required", "string"],
                "description" => ["required", "string"],
                "price" => ["required", "numeric", "gt:0"],
                "surface" => ["required", "integer", "gt:0"],
                "address" => ["required", "string"],
                "dateConstruction" => ["sometimes", "date_format:Y-m-d"],
                "nbEtages" => ["nullable", "integer"],
                "nbRooms" => ["nullable", "integer"],
                "etage" => ["nullable", "integer"],
                "nbBathrooms" => ["nullable", "integer"],
                "latitude" => ["required", "numeric"],
                "longitude" => ["required", "numeric"],
                "tour360Url" => ["nullable", "url:http,https"],
                "category" => ["required", "exists:realstate_categories,code"],
                "typeTransaction" => ["required", "exists:type_transactions,code"],
                "etat" => ["required", "exists:realstate_etats,code"],
                "city" => ["required", "exists:cities,id"],
                "features" => ["nullable", "array"],
                "features.*" => ["exists:features,id"],
                "images" => ["required", "array", "min:2", "max:10"],
                "images.*" => ["image", "mimes:png,jpg,jpeg", "max:2048"]
            ]
        );

        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }

        $data = $validator->validated();

        try {
            DB::beginTransaction();

            // map fields
            $data["date_construction"] = $data["dateConstruction"] ?? null;
            $data["nb_etage"] = $data["nbEtages"] ?? null;
            $data["nb_rooms"] = $data["nbRooms"] ?? null;
            $data["nb_bathroom"] = $data["nbBathrooms"] ?? null;
            $data["tour_360_url"] = $data["tour360Url"] ?? null;
            $data["category_id"] = RealstateCategory::where("code", $data["category"])->first()->id;
            $data["transaction_id"] = TypeTransaction::where("code", $data["typeTransaction"])->first()->id;
            $data["etat_id"] = RealstateEtat::where("code", $data["etat"])->first()->id;
            $data["city_id"] = $data["city"];
            $data["review_status_id"] = RealstateReviewStatus::where("code", "in-review")->first()->id;
            $data["status_id"] = RealstateStatus::where("code", "pending")->first()->id;
            $data["host_id"] = $user->id;

            // create realestate
            $realstate = Realstate::create($data);

            // attach features if present
            if (!empty($data["features"])) {
                $realstate->features()->attach($data["features"]);
            }

            // add images
            $images = $request->file("images");
            foreach ($images as $i => $image) {
                $ext = $image->getClientOriginalExtension();
                $fileName = ($i + 1) . "." . $ext;
                $realstate
                    ->addMedia($image)
                    ->usingFileName($fileName)
                    ->toMediaCollection("images");
            }

            DB::commit();

            // return realestate
            $response = new RealestateResource($realstate);
            return $this->jsonResponse(true, self::SUCCESS, 201, $response);
        } catch (\Throwable $e) {
            DB::rollBack();
            return $this->jsonResponse(false, "Erreur lors de la création du bien immobilier", 500, [
                "error" => $e->getMessage()
            ]);
        }
    }


    /**
     * Display the specified resource.
     */
    public function show(Request $request, $id)
    {
        $user = $request->user();
        $realestate = Realstate::with(["city.region.country", "category", "type", "reviewStatus", "status", "etat", "features", "host"])
            ->where("id", "=", $id)
            ->where("host_id", "=", $user->id)
            ->first();
        if (!$realestate) {
            return $this->jsonResponse(false, self::NOT_FOUND, 404, null);
        }
        $response = new HostRealestateResource($realestate);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }

    /**
     * Update the specified resource in storage.
     */
    // public function update(Request $request, $id)
    // {
    //     $user = $request->user();
    //     $realestate = Realstate::where("id", "=", $id)
    //         ->where("host_id", "=", $user->id)->first();
    //     if (!$realestate) {
    //         return $this->jsonResponse(false, 404, self::NOT_FOUND, null);
    //     }
    //     $validator = Validator::make($request->all(), [
    //         "title" => ["sometimes", "string"],
    //         "description" => ["sometimes", "string"],
    //         "price" => ["sometimes", "numeric", "gt:0"],
    //         "surface" => ["sometimes", "integer", "gt:0"],
    //         "address" => ["sometimes", "string"],
    //         "dateConstruction" => ["sometimes", "date_format:Y-m-d"],
    //         "nbEtages" => ["sometimes", "integer"],
    //         "nbRooms" => ["sometimes", "integer"],
    //         "etage" => ["sometimes", "integer"],
    //         "nbBathrooms" => ["sometimes", "integer"],
    //         "latitude" => ["sometimes", "numeric"],
    //         "longitude" => ["sometimes", "numeric"],
    //         "tour360Url" => ["sometimes", "url:http,https"],
    //         "category" => ["sometimes", "exists:realstate_categories,code"],
    //         "typeTransaction" => ["sometimes", "exists:type_transactions,code"],
    //         "etat" => ["sometimes", "exists:realstate_etats,code"],
    //         "city" => ["sometimes", "exists:cities,id"],
    //         "features.*" => ["sometimes", "exists:features,id"],
    //         "trashImages" => ["sometimes", "array"],
    //         "trashImages.*" => ["sometimes", "integer"],
    //         "images" => ["sometimes", "array"],
    //         "images.*" => ["image", "mimes:png,jpg,jpeg", "max:2048"]
    //     ]);
    //     if ($validator->fails()) {
    //         return $this->jsonResponse(false, self::SUCCESS, 422, $validator->errors());
    //     }

    //     //update
    //     $data = $validator->validated();
    //     $data["date_construction"] = isset($data["dateConstruction"]) ? $data["dateConstruction"] : null;
    //     $data["nb_etage"] = isset($data["nbEtages"]) ? $data["nbEtages"] : null;
    //     $data["nb_rooms"] = isset($data["nbRooms"]) ? $data["nbRooms"] : null;
    //     $data["nb_bathroom"] = isset($data["nbBathrooms"]) ? $data["nbBathrooms"] : null;
    //     $data["tour_360_url"] = isset($data["tour360Url"]) ? $data["tour360Url"] : null;
    //     $data["category_id"] = RealstateCategory::where("code", "=", $data["category"])->first()->id;
    //     $data["transaction_id"] = TypeTransaction::where("code", "=", $data["typeTransaction"])->first()->id;
    //     $data["etat_id"] = RealstateEtat::where("code", "=", $data["etat"])->first()->id;
    //     $data["city_id"] = $data["city"];
    //     $data["review_status_id"] = RealstateReviewStatus::where("code", "=", "in-review")->first()->id;
    //     $data["status_id"] = RealstateStatus::where("code", "=", "pending")->first()->id;
    //     $data["host_id"] = $user->id;

    //     $realestate->update($data);

    //     //update features
    //     if (isset($data['features'])) {
    //         $realestate->features()->sync($data['features']);
    //     }

    //     //add new images
    //     $newImages = $request->file("images");
    //     if ($newImages) {
    //         $start = $realestate->getMedia("images")->max("id");
    //         for ($i = 0; $i < count($newImages); $i++) {
    //             $image = $newImages[$i];
    //             $ext = $image->getClientOriginalExtension();
    //             $fileName = (++$start) . "." . $ext;
    //             $realestate->addMedia($image)->usingFileName($fileName)->toMediaCollection("images");
    //         }
    //     }
    //     //delete images

    //     if ($request->has("trashImages")) {
    //         foreach ($request->input("trashImages") as $imageId) {
    //             $realestate->getMedia("images")->where("id", "=", $imageId)->first()?->delete();
    //         }
    //     }

    //     $realestate->load(["city.region.country", "category", "type", "reviewStatus", "status", "etat", "features", "host"]);
    //     $realestate->unsetRelation('media');
    //     $realestate->loadMedia("images");
    //     $data = new HostRealestateResource($realestate);
    //     return $this->jsonResponse(true, self::SUCCESS, 200, $data);
    // }

    public function update(Request $request, $id)
    {
        $user = $request->user();
        $realestate = Realstate::where("id", "=", $id)
            ->where("host_id", "=", $user->id)->first();

        if (!$realestate) {
            return $this->jsonResponse(false, 404, self::NOT_FOUND, null);
        }

        $validator = Validator::make($request->all(), [
            "title" => ["sometimes", "string"],
            "description" => ["sometimes", "string"],
            "price" => ["sometimes", "numeric", "gt:0"],
            "surface" => ["sometimes", "integer", "gt:0"],
            "address" => ["sometimes", "string"],
            "dateConstruction" => ["sometimes", "date_format:Y-m-d"],
            "nbEtages" => ["nullable", "integer"],
            "nbRooms" => ["nullable", "integer"],
            "etage" => ["nullable", "integer"],
            "nbBathrooms" => ["nullable", "integer"],
            "latitude" => ["sometimes", "numeric"],
            "longitude" => ["sometimes", "numeric"],
            "tour360Url" => ["nullable", "url:http,https"],
            "category" => ["sometimes", "exists:realstate_categories,code"],
            "typeTransaction" => ["sometimes", "exists:type_transactions,code"],
            "etat" => ["sometimes", "exists:realstate_etats,code"],
            "city" => ["sometimes", "exists:cities,id"],
            "features" => ["nullable", "array"],
            "features.*" => ["sometimes", "exists:features,id"],
            "trashImages" => ["sometimes", "array"],
            "trashImages.*" => ["sometimes", "integer"],
            "images" => ["sometimes", "array"],
            "images.*" => ["image", "mimes:png,jpg,jpeg", "max:2048"]
        ]);

        if ($validator->fails()) {
            return $this->jsonResponse(false, self::SUCCESS, 422, $validator->errors());
        }

        DB::beginTransaction();

        try {
            // update realestate data
            $data = $validator->validated();
            $data["date_construction"] = $data["dateConstruction"] ?? null;
            $data["nb_etage"] = $data["nbEtages"] ?? null;
            $data["nb_rooms"] = $data["nbRooms"] ?? null;
            $data["nb_bathroom"] = $data["nbBathrooms"] ?? null;
            $data["tour_360_url"] = $data["tour360Url"] ?? null;

            if (isset($data["category"])) {
                $data["category_id"] = RealstateCategory::where("code", "=", $data["category"])->first()->id;
            }
            if (isset($data["typeTransaction"])) {
                $data["transaction_id"] = TypeTransaction::where("code", "=", $data["typeTransaction"])->first()->id;
            }
            if (isset($data["etat"])) {
                $data["etat_id"] = RealstateEtat::where("code", "=", $data["etat"])->first()->id;
            }
            if (isset($data["city"])) {
                $data["city_id"] = $data["city"];
            }

            $data["review_status_id"] = RealstateReviewStatus::where("code", "=", "in-review")->first()->id;
            $data["status_id"] = RealstateStatus::where("code", "=", "pending")->first()->id;
            $data["host_id"] = $user->id;

            $realestate->update($data);

            // update features
            if (isset($data['features'])) {
                $realestate->features()->sync($data['features']);
            }

            // add new images
            $newImages = $request->file("images");
            if ($newImages) {
                $start = $realestate->getMedia("images")->max("id");
                foreach ($newImages as $image) {
                    $ext = $image->getClientOriginalExtension();
                    $fileName = (++$start) . "." . $ext;
                    $realestate->addMedia($image)
                        ->usingFileName($fileName)
                        ->toMediaCollection("images");
                }
            }

            // delete images
            if ($request->has("trashImages")) {
                foreach ($request->input("trashImages") as $imageId) {
                    $realestate->getMedia("images")
                        ->where("id", "=", $imageId)
                        ->first()?->delete();
                }
            }

            DB::commit();

            $realestate->load([
                "city.region.country",
                "category",
                "type",
                "reviewStatus",
                "status",
                "etat",
                "features",
                "host"
            ]);
            $realestate->unsetRelation('media');
            $realestate->loadMedia("images");

            $data = new HostRealestateResource($realestate);
            return $this->jsonResponse(true, self::SUCCESS, 200, $data);
        } catch (\Exception $e) {
            DB::rollBack();
            return $this->jsonResponse(false, "SERVER ERROR", 500, $e->getMessage());
        }
    }



    public function destroy(Request $request, $id)
    {
        $user = $request->user();
        $realstate = Realstate::where("id", "=", $id)
            ->where("host_id", "=", $user->id)
            ->first();

        if (!$realstate) {
            return $this->jsonResponse(false, self::NOT_FOUND, 404, null);
        }
        $realstate->update(
            ["is_deleted" => 1]
        );
        return $this->jsonResponse(true, self::SUCCESS, 200, null);
    }


    public function activate(Request $request, $id)
    {
        $user = $request->user();
        $realstate = Realstate::where("id", "=", $id)
            ->where("host_id", "=", $user->id)
            ->first();

        if (!$realstate) {
            return $this->jsonResponse(false, self::NOT_FOUND, 404, null);
        }
        if ($realstate->status->code != "paused") {
            return $this->jsonResponse(false, "not-paused", 406, null);
        }
        $newStatus = RealstateStatus::where("code", "=", "active")->first()?->id;
        $realstate->update([
            "status_id" => $newStatus
        ]);
        $response = new HostRealestateResource($realstate);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }

    public function pause(Request $request, $id)
    {
        $user = $request->user();
        $realstate = Realstate::where("id", "=", $id)
            ->where("host_id", "=", $user->id)
            ->first();

        if (!$realstate) {
            return $this->jsonResponse(false, self::NOT_FOUND, 404, null);
        }
        if ($realstate->status->code != "active") {
            return $this->jsonResponse(false, "not-active", 406, null);
        }
        $newStatus = RealstateStatus::where("code", "=", "paused")->first()?->id;
        $realstate->update([
            "status_id" => $newStatus
        ]);
        $response = new HostRealestateResource($realstate);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }
}
