<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Models\Slider;
use App\utils\JsonResponses;
use Illuminate\Http\Request;

class HomeImages extends Controller
{
    use JsonResponses;
    public function index()
    {
        $baseUrl = env("APP_URL");
        // $images = [
        //     $baseUrl . "/storage/slides/slider1.png",
        //     $baseUrl . "/storage/slides/slider2.png",
        //     $baseUrl . "/storage/slides/slider3.png",
        // ];
        $images = null;
        $slider = Slider::where("is_active", true)->first();
        if ($slider) {
            $images = $slider->getMedia("images")->collect()->map(function ($media) {
                return $media->original_url;
            });
        } else {
            $images = [
                $baseUrl . "/storage/slides/slider1.png",
                $baseUrl . "/storage/slides/slider2.png",
                $baseUrl . "/storage/slides/slider3.png",
            ];
        }
        return $this->jsonResponse(true, self::SUCCESS, 200, $images);
    }
}
