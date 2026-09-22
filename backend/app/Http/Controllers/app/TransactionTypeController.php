<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\TransactionTypeResource;
use App\Models\TypeTransaction;
use App\utils\JsonResponses;
use Illuminate\Http\Request;

class TransactionTypeController extends Controller
{
    use JsonResponses;


    public function index(Request $request)
    {
        $types = TypeTransaction::all();
        $data = TransactionTypeResource::collection($types);
        return $this->jsonResponse(true, self::SUCCESS, 200, $data);
    }
}
