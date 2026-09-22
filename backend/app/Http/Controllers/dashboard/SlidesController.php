<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\DashboardResource\SliderResource;
use App\Models\Slider;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use PhpParser\Node\Expr\Throw_;
use Throwable;

class SlidesController extends Controller
{

    use JsonResponses;


    public function index()
    {
        $sliders = Slider::query()->orderBy("created_at", "desc")->get();
        $response = SliderResource::collection($sliders);
        return $this->successResponse($response);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "name" => ["required",],
            "description" => ["required"],
            "images" => ["required", "array", "min:2"],
            "images.*" => ["image", "mimes:png,jpg,jpeg"]
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }
        $data = $validator->validated();
        $data["is_active"] = true;
        DB::beginTransaction();
        try {
            $slider = Slider::create($data);
            $images = $request->file("images");
            foreach ($images as $image) {
                $slider->addMedia($image)->toMediaCollection("images");
            }
            $slider->refresh();
            $this->disableSliders($slider->id);
            DB::commit();
            $response = new SliderResource($slider);
            return $this->createdResponse($response);
        } catch (Throwable $th) {
            DB::rollBack();
            return $this->serverErrorResponse(null);
        }
    }



    public function disableSliders($id)
    {
        Slider::where("id", "!=", $id)->update(
            [
                "is_active" => false
            ]
        );
    }

    public function activate($id)
    {
        $slider = Slider::find($id);
        DB::beginTransaction();
        try {
            $slider->is_active = true;
            $slider->save();
            $this->disableSliders($id);
            DB::commit();
            $response = new SliderResource($slider->fresh());
            return $this->successResponse($response);
        } catch (Throwable $th) {
            DB::rollBack();
            return $this->serverErrorResponse(null);
        }
    }
}
