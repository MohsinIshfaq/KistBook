<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Services\PlanServiceInterface;
use App\Http\Controllers\Controller;
use App\Http\Requests\Plans\StorePlanRequest;
use App\Http\Requests\Plans\UpdatePlanRequest;
use App\Http\Resources\PlanResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PlanController extends Controller
{
    public function __construct(private readonly PlanServiceInterface $plans)
    {
    }

    public function index(Request $request): JsonResponse
    {
        return $this->successResponse(PlanResource::collection($this->plans->list((int) $request->integer('perPage', $request->integer('per_page', 15)))));
    }

    public function store(StorePlanRequest $request): JsonResponse
    {
        return $this->successResponse(new PlanResource($this->plans->create($request->validated())), 'Plan created successfully.', 201);
    }

    public function show(string $uuid): JsonResponse
    {
        return $this->successResponse(new PlanResource($this->plans->show($uuid)));
    }

    public function update(UpdatePlanRequest $request, string $uuid): JsonResponse
    {
        return $this->successResponse(new PlanResource($this->plans->update($uuid, $request->validated())), 'Plan updated successfully.');
    }

    public function destroy(string $uuid): JsonResponse
    {
        $this->plans->delete($uuid);

        return $this->successResponse(null, 'Plan deleted successfully.');
    }
}
