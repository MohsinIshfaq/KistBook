<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\RuntimeBootstrapService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RuntimeBootstrapController extends Controller
{
    public function __construct(private readonly RuntimeBootstrapService $bootstrap) {}

    public function show(Request $request): JsonResponse
    {
        return $this->successResponse(
            $this->bootstrap->bootstrap($request->user()),
            'Runtime bootstrap data fetched successfully.',
        );
    }
}
