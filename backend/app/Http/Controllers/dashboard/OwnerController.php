<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\DashboardResource\OwnerResource;
use App\Models\Owner;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class OwnerController extends Controller
{
    use JsonResponses;

    // List all owners
    public function index()
    {
        $owners = Owner::all();
        $response = OwnerResource::collection($owners);
        return $this->successResponse($response);
    }

    // Show a single owner


    // Create a new owner
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "name" => ["required", "min:4"],
            "email" => ["nullable", "email"],
            "tel" => ["required", "regex:/^\d{10,}$/"],
            "address" => ["nullable", "string"],
            "rib" => ["nullable"]
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }
        $owner = Owner::create($validator->validated());
        $response = new OwnerResource($owner);
        return $this->createdResponse($response);
    }

    // Update an owner
    public function update(Request $request, $id)
    {
        $owner = Owner::find($id);
        if (!$owner) {
            return $this->notFoundResponse('Owner not found');
        }
        $validator = Validator::make($request->all(), [
            "name" => ["sometimes", "min:4"],
            "email" => ["sometimes", "email"],
            "tel" => ["sometimes", "regex:/^\d{10,}$/"],
            "address" => ["nullable", "string"]
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }
        $owner->update($validator->validated());
        return $this->successResponse(new OwnerResource($owner));
    }

    public function show(Request $request, $id)
    {
        $owner = Owner::with(["realestates.status", "realestates.type", "realestates.dossier"])->find($id);
        if (!$owner) {
            return $this->notFoundResponse('Owner not found');
        }
        return new OwnerResource($owner);
    }

    public function destroy($id)
    {
        $owner = Owner::find($id);

        if (!$owner) {
            return $this->notFoundResponse('Owner not found');
        }

        $owner->delete();

        return $this->successResponse(null);
    }
}
