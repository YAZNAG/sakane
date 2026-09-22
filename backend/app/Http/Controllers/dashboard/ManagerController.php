<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\DashboardResource\ManagerResource;
use App\Models\Manager;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Spatie\Permission\Models\Role;

class ManagerController extends Controller
{

    use JsonResponses;

    public function index()
    {
        $managers = Manager::query()->orderBy("created_at", "desc")->get();
        $response = ManagerResource::collection($managers);
        return $this->successResponse($response);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "firstName" => ["required", "min:3"],
            "lastName" => ["required", "min:3"],
            "email" => ["required", "email", "unique:managers,email"],
            "role" => ["required"],
            "phone" => ["required"],
            "password" => ["required", "min:4"]
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }
        $data = $validator->validated();
        $data["first_name"] = $data["firstName"];
        $data["last_name"] = $data["lastName"];
        $data["password"] = Hash::make($data["password"]);

        $manager = Manager::create($data);
        $manager->assignRole($request->input("role"));
        $response = new ManagerResource($manager->fresh());
        return $this->createdResponse($response);
    }

    public function update(Request $request, $id)
    {
        $manager = Manager::findOrFail($id);

        $validator = Validator::make($request->all(), [
            "firstName" => ["sometimes", "min:3"],
            "lastName" => ["sometimes", "min:3"],
            "role" => ["sometimes"],
            "phone" => ["sometimes"],
            "password" => ["sometimes", "min:4"]
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $data = $validator->validated();

        // Map camelCase to snake_case
        if (isset($data["firstName"])) {
            $data["first_name"] = $data["firstName"];
            unset($data["firstName"]);
        }
        if (isset($data["lastName"])) {
            $data["last_name"] = $data["lastName"];
            unset($data["lastName"]);
        }
        if (isset($data["password"])) {
            $data["password"] = Hash::make($data["password"]);
        }

        // Remove role from data array as it's handled separately
        $role = $data["role"] ?? null;
        unset($data["role"]);

        $manager->update($data);

        // Update role if provided
        if ($role) {
            $manager->syncRoles([$role]);
        }

        $response = new ManagerResource($manager->fresh());
        return $this->successResponse($response);
    }

    public function show($id)
    {
        $manager = Manager::findOrFail($id);
        $response = new ManagerResource($manager);
        return $this->successResponse($response);
    }

    public function destroy($id)
    {
        $manager = Manager::findOrFail($id);
        $manager->delete();

        return $this->successResponse(null);
    }

    public function roles()
    {
        $roles = Role::all()->pluck("name");
        return $this->successResponse($roles);
    }
}
