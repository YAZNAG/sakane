<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\CategoryResource;
use App\Models\RealstateCategory;
use App\utils\JsonResponses;
use Illuminate\Http\Request;

class CategoryController extends Controller
{
    use JsonResponses;
    public function index(Request $request)
    {
        $categories = RealstateCategory::all();
        $data = CategoryResource::collection($categories);
        return $this->jsonResponse(true, self::SUCCESS, 200, $data);
    }
}
