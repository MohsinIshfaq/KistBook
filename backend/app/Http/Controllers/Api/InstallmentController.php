<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Services\InstallmentServiceInterface;
use App\Http\Controllers\Controller;
use App\Http\Requests\Installments\StoreInstallmentRequest;
use App\Http\Requests\Installments\UpdateInstallmentRequest;
use App\Http\Resources\InstallmentResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class InstallmentController extends Controller
{
    public function __construct(private readonly InstallmentServiceInterface $installments)
    {
    }

    public function index(Request $request): JsonResponse
    {
        return $this->successResponse(InstallmentResource::collection($this->installments->list((int) $request->integer('per_page', 15))));
    }

    public function store(StoreInstallmentRequest $request): JsonResponse
    {
        return $this->successResponse(new InstallmentResource($this->installments->create($request->validated())), 'Installment created successfully.', 201);
    }

    public function show(string $uuid): JsonResponse
    {
        return $this->successResponse(new InstallmentResource($this->installments->show($uuid)));
    }

    public function update(UpdateInstallmentRequest $request, string $uuid): JsonResponse
    {
        return $this->successResponse(new InstallmentResource($this->installments->update($uuid, $request->validated())), 'Installment updated successfully.');
    }

    public function destroy(string $uuid): JsonResponse
    {
        $this->installments->delete($uuid);

        return $this->successResponse(null, 'Installment deleted successfully.');
    }
}
