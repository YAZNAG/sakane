<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\DashboardResource\ProgramedChargeResource;
use App\Models\ProgramedCharge;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class ProgramedChargesController extends Controller
{
    use JsonResponses;


    public function index(Request $request)
    {
        $realestate = $request->input("realestate");

        $programedCharges = ProgramedCharge::with("realestate")
            ->where("realestate_id", $realestate)
            ->orderBy("created_at", "desc")
            ->get();

        return $this->successResponse(ProgramedChargeResource::collection($programedCharges));
    }

    public function store(Request $request)
    {
        $rules = [
            "nom"          => ["required", "string"],
            "description"  => ["required", "string"],
            "amount"       => ["required", "numeric"],
            "type"         => ["required", "in:week,month,year"],
            "realestate"   => ["nullable", "exists:realstates,id"],
        ];

        // Conditional rules based on type
        if ($request->input("type") === "week") {
            $rules["dayName"] = ["required", "in:Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday"];
        } elseif ($request->input("type") === "month") {
            $rules["day"] = ["required", "integer", "between:1,30"];
        } elseif ($request->input("type") === "year") {
            $rules["month"] = ["required", "integer", "between:1,12"];
            $rules["day"]   = ["required", "integer", "between:1,30"];
        }

        $validator = Validator::make($request->all(), $rules);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $data = $validator->validated();

        // Map realestate -> realestate_id
        $data["realestate_id"] = $data["realestate"] ?? null;
        $data["day_name"] = $data["dayName"] ?? null;
        unset($data["realestate"], $data["dayName"]);

        // Nullify fields that are irrelevant to the selected type
        if ($data["type"] === "week") {
            $data["day"]   = null;
            $data["month"] = null;
        } elseif ($data["type"] === "month") {
            $data["day_name"] = null;
            $data["month"]    = null;
        } elseif ($data["type"] === "year") {
            $data["day_name"] = null;
        }

        $programedCharge = ProgramedCharge::create($data);

        return $this->createdResponse(new ProgramedChargeResource($programedCharge));
    }

    public function update(Request $request, $id)
    {
        $programedCharge = ProgramedCharge::find($id);

        if (!$programedCharge) {
            return $this->notFoundResponse();
        }

        // Use the incoming type if provided, otherwise fall back to the existing one
        $type = $request->input("type", $programedCharge->type);

        $rules = [
            "nom"         => ["sometimes", "string"],
            "description" => ["sometimes", "string"],
            "amount"      => ["sometimes", "numeric"],
            "type"        => ["sometimes", "in:week,month,year"],
            "realestate"  => ["nullable", "exists:realstates,id"],
        ];

        if ($type === "week") {
            $rules["dayName"] = ["required", "in:Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday"];
        } elseif ($type === "month") {
            $rules["day"] = ["required", "integer", "between:1,30"];
        } elseif ($type === "year") {
            $rules["month"] = ["required", "integer", "between:1,12"];
            $rules["day"]   = ["required", "integer", "between:1,30"];
        }

        $validator = Validator::make($request->all(), $rules);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $data = $validator->validated();

        // Map realestate -> realestate_id
        if (array_key_exists("realestate", $data)) {
            $data["realestate_id"] = $data["realestate"] ?? null;
            unset($data["realestate"]);
        }

        if (array_key_exists("dayName", $data)) {
            $data["day_name"] = $data["dayName"] ?? null;
            unset($data["dayName"]);
        }

        // Nullify irrelevant fields based on the resolved type
        if ($type === "week") {
            $data["day"]   = null;
            $data["month"] = null;
        } elseif ($type === "month") {
            $data["day_name"] = null;
            $data["month"]    = null;
        } elseif ($type === "year") {
            $data["day_name"] = null;
        }

        $programedCharge->update($data);

        return $this->successResponse(new ProgramedChargeResource($programedCharge));
    }

    public function show($id)
    {
        $programedCharge = ProgramedCharge::with("realestate")->find($id);

        if (!$programedCharge) {
            return $this->notFoundResponse();
        }

        return $this->successResponse(new ProgramedChargeResource($programedCharge));
    }


    public function delete($id)
    {
        // Droit a part : supprimer une charge programmee n'est pas supprimer une charge.
        $m = request()->user();
        if (!request()->attributes->get("droit_verifie") && (!$m || !($m->hasRole("admin") || $m->can("delete_programed_charge") || $m->can("delete_charge")))) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403, ["msg" => ["Vous n'avez pas l'autorisation de supprimer une charge programmée."]]);
        }
        $programedCharge = ProgramedCharge::find($id);

        if (!$programedCharge) {
            return $this->notFoundResponse();
        }

        $programedCharge->delete(); // soft delete if enabled

        return $this->successResponse(null);
    }
}
