<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\DashboardResource\ContractResource;
use App\Models\Contract;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class ContractsController extends Controller
{
    use JsonResponses;

    // List all contracts
    public function index(Request $request)
    {
        $realestate = $request->input("realestate");
        $contracts = Contract::with(['media', "owner", "client", "realestate"])
            ->when($realestate, function ($query) use ($realestate) {
                $query->where("realestate_id", "=", $realestate);
            })->orderBy("signed_date", "desc")
            ->get();

        $response = ContractResource::collection($contracts);
        return $this->successResponse($response);
    }

    // Show a single contract
    public function show($id)
    {
        $contract = Contract::with('media')->find($id);
        if (!$contract) {
            return $this->notFoundResponse('Contract not found');
        }
        return $this->successResponse(new ContractResource($contract));
    }

    // Create a new contract with documents
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'note' => ['nullable', 'string'],
            'owner' => ['nullable', 'exists:owners,id'],
            'client' => ['nullable', 'exists:users,id'],
            'signed' => ['required', 'date'],
            'expiration' => ['required', 'date'],
            'realestate' => ['sometimes', 'exists:realstates,id'],
            'documents.*' => ['file', 'mimes:jpeg,png,pdf']
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }
        $data = $validator->validated();
        $data["owner_id"] = isset($data["owner"]) ? $data["owner"] : null;
        $data["client_id"] = isset($data["client"]) ? $data["client"] : null;
        $data["realestate_id"] = isset($data["realestate"]) ? $data["realestate"] : null;
        $data["signed_date"] = $data["signed"];
        $data["signed_data"] = $data["signed"];
        $data["expiration_date"] = $data["expiration"];


        $contract = Contract::create($data);
        if ($request->hasFile('documents')) {
            foreach ($request->file('documents') as $file) {
                $contract->addMedia($file)->toMediaCollection('documents');
            }
        }
        $response = new ContractResource($contract->load('media'));

        return $this->createdResponse($response);
    }

    // Update a contract and documents
    public function update(Request $request, $id)
    {
        $contract = Contract::find($id);
        if (!$contract) {
            return $this->notFoundResponse('Contract not found');
        }
        $validator = Validator::make($request->all(), [
            'note' => ['nullable', 'string'],
            'owner' => ['sometimes', 'integer', 'exists:owners,id'],
            'client' => ['sometimes', 'integer', "exists:users,id"],
            'signed' => ['sometimes', 'date'],
            'expiration' => ['sometimes', 'date'],
            'realestate' => ['sometimes', 'integer', 'exists:realstates,id'],
            'trashDocuments' => ["array"],
            'trashDocuments.*' => ["integer"],
            'documents.*' => ['file', 'mimes:jpeg,png,pdf']
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }
        $data = $validator->validated();
        if (isset($data["owner"])) {
            $data["owner_id"] = $data["owner"];
        }
        if (isset($data["client"])) {
            $data["client_id"] = $data["client"];
        }
        if (isset($data["signed"])) {
            $data["signed_data"] = $data["signed"];
        }
        if (isset($data["expiration"])) {
            $data["expiration_date"] = $data["expiration"];
        }
        if (isset($data["realestate"])) {
            $data["realestate_id"] = $data["realestate"];
        }
        $contract->update($data);

        if ($request->has("trashDocuments")) {
            foreach ($request->input("trashDocuments") as $doc) {
                $media = $contract->media()->where("id", "=", $doc)->first();
                $media?->delete();
            }
        }
        if ($request->hasFile('documents')) {

            foreach ($request->file('documents') as $file) {
                $contract->addMedia($file)->toMediaCollection('documents');
            }
        }
        return $this->successResponse($contract->load('media'));
    }

    public function delete($id)
    {
        $contract = Contract::find($id);

        if (!$contract) {
            return $this->notFoundResponse('Contract not found');
        }

        // Optional: delete related media (if you want to clean storage)
        //$contract->clearMediaCollection('documents');

        $contract->delete(); // soft delete if enabled

        return $this->successResponse(null);
    }
}
