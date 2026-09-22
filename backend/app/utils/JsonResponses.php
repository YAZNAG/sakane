<?php

namespace App\utils;

use Illuminate\Support\Facades\Response;

trait JsonResponses
{
    // Success response
    public function successResponse($data, $message = 'OK', $statusCode = 200)
    {
        return $this->jsonResponse(true, $message, $statusCode, $data);
    }

    // Not found response
    public function notFoundResponse($message = 'Not found', $statusCode = 404)
    {
        return $this->jsonResponse(false, $message, $statusCode, null);
    }

    public function serverErrorResponse($errors, $message = 'Server error', $statusCode = 500)
    {
        return $this->jsonResponse(false, $message, $statusCode, $errors);
    }

    // Validation error response
    public function validationErrorResponse($errors, $message = 'Validation error', $statusCode = 422)
    {
        return $this->jsonResponse(false, $message, $statusCode, $errors);
    }

    // Created response
    public function createdResponse($data, $message = 'Created', $statusCode = 201)
    {
        return $this->jsonResponse(true, $message, $statusCode, $data);
    }

    private const VALIDATION_ERROR = "validation-error";
    private const SUCCESS = "success";
    private const NOT_FOUND = "not found";
    private const NO_ACCESS = "don't-have-access";

    private function jsonResponse($isSuccess, $message, $statusCode, $content)
    {
        $response = [
            "success" => $isSuccess,
            "statusCode" => $statusCode,
            "message" => $message,
        ];
        if ($isSuccess) {
            $response["data"] = $content;
        } else {
            $response["error"] = $content;
        }
        return Response()->json($response, $statusCode);
    }

    // private function jsonResponseWithPagination($isSuccess, $message, $statusCode, $content)
    // {
    //     $response = [
    //         "success" => $isSuccess,
    //         "statusCode" => $statusCode,
    //         "message" => $message,
    //     ];
    //     if ($isSuccess) {
    //         $response["data"] = $content->items;
    //         $response["pagination"] = [
    //             'total'         => $content->total(),
    //             'per_page'      => $content->perPage(),
    //             'current_page'  => $content->currentPage(),
    //             'last_page'     => $content->lastPage(),
    //             'from'          => $content->firstItem(),
    //             'to'            => $content->lastItem()
    //         ];
    //     } else {
    //         $response["error"] = $content;
    //     }
    //     return Response()->json($response, $statusCode);
    // }
}
