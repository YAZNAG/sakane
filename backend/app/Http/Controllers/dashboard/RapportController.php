<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\DashboardResource\RapportResource;
use App\Models\RealestateRapport;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Throwable;

class RapportController extends Controller
{

    use JsonResponses;

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "name" => ["required"],
            "description" => ["nullable"],
            "date" => ["required"],
            "realestate" => ["required", "exists:realstates,id"],
            "images" => ["required"]
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }
        DB::beginTransaction();
        try {
            $data = $validator->validated();
            $data["realestate_id"] = $data["realestate"];
            $rapport = RealestateRapport::create($data);
            $images = $request->file('images');
            foreach ($images as $image) {
                $rapport->addMedia($image)->toMediaCollection("images");
            }
            $response = new RapportResource($rapport->fresh());
            DB::commit();
            return $this->createdResponse($response);
        } catch (Throwable $th) {
            DB::rollBack();
            //throw $th;
            return $this->serverErrorResponse(null);
        }
    }


    public function index(Request $request)
    {
        $realestate = $request->input("realestate");
        $rapports = RealestateRapport::when($realestate, function ($query) use ($realestate) {
            $query->where("realestate_id", $realestate);
        })->orderBy("created_at", "desc")
            ->get();
        $response = RapportResource::collection($rapports);
        return $this->successResponse($response);
    }


    public function update(Request $request, $id)
    {
        $rapport = RealestateRapport::find($id);

        if (!$rapport) {
            return $this->notFoundResponse();
        }

        $validator = Validator::make($request->all(), [
            "name" => ["sometimes"],
            "description" => ["nullable"],
            "date" => ["sometimes"],
            "realestate" => ["sometimes", "exists:realstates,id"],
            "images" => ["sometimes", "array"],
            "images.*" => ["image", "mimes:png,jpg,jpeg"],
            "trashImages" => ["sometimes", "array"],
            "trashImages.*" => ["integer"]
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        DB::beginTransaction();

        try {
            $data = $validator->validated();

            // Map realestate
            if (isset($data["realestate"])) {
                $data["realestate_id"] = $data["realestate"];
                unset($data["realestate"]);
            }

            $rapport->update($data);

            // Delete selected images
            if ($request->has("trashImages")) {
                foreach ($request->input("trashImages") as $imgId) {
                    $rapport->getMedia("images")->where("id", $imgId)->first()?->delete();
                }
            }

            // Add new images
            if ($request->hasFile("images")) {
                foreach ($request->file("images") as $image) {
                    $rapport->addMedia($image)->toMediaCollection("images");
                }
            }

            DB::commit();

            return $this->successResponse(new RapportResource($rapport->fresh()));
        } catch (Throwable $th) {
            DB::rollBack();
            return $this->serverErrorResponse(null);
        }
    }


    public function delete($id)
    {
        $rapport = RealestateRapport::find($id);

        if (!$rapport) {
            return $this->notFoundResponse();
        }

        // Optional: delete all images
        $rapport->clearMediaCollection("images");

        $rapport->delete(); // soft delete if enabled

        return $this->successResponse(null);
    }
}
