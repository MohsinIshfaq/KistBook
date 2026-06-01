<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Plans\UpsertInstallmentPlanRequest;
use App\Http\Resources\InstallmentPlanResource;
use App\Services\InstallmentPlanService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class InstallmentPlanController extends Controller
{
    public function __construct(private readonly InstallmentPlanService $plans) {}

    public function index(Request $request): JsonResponse
    {
        return $this->successResponse(InstallmentPlanResource::collection($this->plans->list(
            $request->user(),
            max(1, min(100, (int) $request->integer('perPage', $request->integer('per_page', 15)))),
            $request->string('search')->trim()->toString() ?: null,
        )));
    }

    public function store(UpsertInstallmentPlanRequest $request): JsonResponse
    {
        return $this->successResponse(new InstallmentPlanResource($this->plans->create($request->user(), $request->validated())), 'Installment plan created successfully.', 201);
    }

    public function show(Request $request, string $uuid): JsonResponse
    {
        return $this->successResponse(new InstallmentPlanResource($this->plans->show($request->user(), $uuid)));
    }

    public function update(UpsertInstallmentPlanRequest $request, string $uuid): JsonResponse
    {
        return $this->successResponse(new InstallmentPlanResource($this->plans->update($request->user(), $uuid, $request->validated())), 'Installment plan updated successfully.');
    }

    public function destroy(Request $request, string $uuid): JsonResponse
    {
        $this->plans->delete($request->user(), $uuid);

        return $this->successResponse(null, 'Installment plan deleted successfully.');
    }
}
