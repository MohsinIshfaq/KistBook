<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Services\PaymentServiceInterface;
use App\Http\Controllers\Controller;
use App\Http\Requests\Payments\StorePaymentRequest;
use App\Http\Requests\Payments\UpdatePaymentRequest;
use App\Http\Resources\PaymentResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PaymentController extends Controller
{
    public function __construct(private readonly PaymentServiceInterface $payments)
    {
    }

    public function index(Request $request): JsonResponse
    {
        return $this->successResponse(PaymentResource::collection($this->payments->list((int) $request->integer('per_page', 15))));
    }

    public function store(StorePaymentRequest $request): JsonResponse
    {
        $payload = $request->validated();
        $payload['created_by'] = $payload['created_by'] ?? $request->user()->uuid;

        return $this->successResponse(new PaymentResource($this->payments->create($payload)), 'Payment created successfully.', 201);
    }

    public function show(string $uuid): JsonResponse
    {
        return $this->successResponse(new PaymentResource($this->payments->show($uuid)));
    }

    public function update(UpdatePaymentRequest $request, string $uuid): JsonResponse
    {
        return $this->successResponse(new PaymentResource($this->payments->update($uuid, $request->validated())), 'Payment updated successfully.');
    }

    public function destroy(string $uuid): JsonResponse
    {
        $this->payments->delete($uuid);

        return $this->successResponse(null, 'Payment deleted successfully.');
    }
}
