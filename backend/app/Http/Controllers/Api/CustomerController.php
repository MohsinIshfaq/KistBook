<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Services\CustomerServiceInterface;
use App\Http\Controllers\Controller;
use App\Http\Requests\Customers\StoreCustomerRequest;
use App\Http\Requests\Customers\UpdateCustomerRequest;
use App\Http\Resources\CustomerResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    public function __construct(private readonly CustomerServiceInterface $customers)
    {
    }

    public function index(Request $request): JsonResponse
    {
        return $this->successResponse(CustomerResource::collection($this->customers->list((int) $request->integer('per_page', 15))));
    }

    public function store(StoreCustomerRequest $request): JsonResponse
    {
        return $this->successResponse(new CustomerResource($this->customers->create($request->validated())), 'Customer created successfully.', 201);
    }

    public function show(string $uuid): JsonResponse
    {
        return $this->successResponse(new CustomerResource($this->customers->show($uuid)));
    }

    public function update(UpdateCustomerRequest $request, string $uuid): JsonResponse
    {
        return $this->successResponse(new CustomerResource($this->customers->update($uuid, $request->validated())), 'Customer updated successfully.');
    }

    public function destroy(string $uuid): JsonResponse
    {
        $this->customers->delete($uuid);

        return $this->successResponse(null, 'Customer deleted successfully.');
    }
}
