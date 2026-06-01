<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Services\CustomerServiceInterface;
use App\Http\Controllers\Controller;
use App\Http\Resources\CustomerResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    public function __construct(private readonly CustomerServiceInterface $customers)
    {
    }

    public function show(Request $request, string $uuid): JsonResponse
    {
        return $this->successResponse(new CustomerResource($this->customers->show($request->user(), $uuid)));
    }
}
