<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Services\CustomerServiceInterface;
use App\Http\Controllers\Controller;
use App\Http\Resources\CustomerResource;
use App\Services\CustomerPlanDetailService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    public function __construct(
        private readonly CustomerServiceInterface $customers,
        private readonly CustomerPlanDetailService $planDetails,
    ) {}

    public function show(Request $request, string $uuid): JsonResponse
    {
        return $this->successResponse(new CustomerResource($this->customers->show($request->user(), $uuid)));
    }

    public function plans(Request $request, string $uuid): JsonResponse
    {
        return response()->json([
            'success' => true,
            'message' => 'Customer plan details fetched successfully.',
            'serverTime' => now()->toJSON(),
            'data' => $this->planDetails->show($request->user(), $uuid),
        ]);
    }
}
