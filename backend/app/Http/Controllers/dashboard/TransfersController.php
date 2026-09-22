<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\OperationType;
use App\Models\Transaction;
use App\Models\User;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Throwable;

class TransfersController extends Controller
{
    use JsonResponses;
    public function addTransfert(Request $request)
    {
        $user = $request->user();
        $validator = Validator::make($request->all(), [
            "host" => ["required", "exists:users,id"],
            "amount" => ["required", "numeric"],
            "document" => ["sometimes", "file", "mimes:jpg,jpeg,pg,pdf"]
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }
        $host = User::find($request->input("host"));
        if ($host->type->code != "host") {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, [
                "host" => ["hôte invalide"]
            ]);
        }
        if ($host->balance < $request->input("amount")) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, [
                "amount" => ["montant invalide"]
            ]);
        }
        $operation = OperationType::where("code", "=", "transfert")->first();
        $data = $validator->validated();
        $data["user_id"] = $data["host"];
        $data["operation_id"] = $operation->id;
        DB::beginTransaction();
        try {

            $Transaction = Transaction::create($data);
            if ($request->hasFile("document")) {
                $document = $request->file("document");
                $ext = $document->getClientOriginalExtension();
                $fileName = "document." . $ext;
                $Transaction->addMedia($document)
                    ->usingFileName($fileName)
                    ->toMediaCollection("document");
            }
            $host->balance -= $data["amount"];
            $host->save();
            DB::commit();
            return $this->jsonResponse(true, self::SUCCESS, 200, null);
        } catch (Throwable $th) {
            DB::rollBack();
            Log::error("add-transfert:" . $th->getMessage());
        }
    }
    
}
