<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Plans\InstallmentPlanSyncMutationRequest;
use App\Services\InstallmentPlanSyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class InstallmentPlanSyncController extends Controller
{
    public function __construct(private readonly InstallmentPlanSyncService $sync) {}

    public function download(Request $request): JsonResponse
    {
        $maxLimit = max(1, min(10, (int) config('kistbook.installment_plan_sync.max_limit', 10)));
        $validated = $request->validate([
            'lastUpdatedAt' => ['nullable', 'date', 'required_with:lastServerId'],
            'lastServerId' => ['nullable', 'uuid'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:'.$maxLimit],
        ]);

        return response()->json($this->sync->download(
            $request->user(),
            $validated['lastUpdatedAt'] ?? null,
            (int) ($validated['limit'] ?? min($maxLimit, max(1, (int) config('kistbook.installment_plan_sync.default_limit', 10)))),
            $validated['lastServerId'] ?? null,
        ));
    }

    public function create(InstallmentPlanSyncMutationRequest $request): JsonResponse
    {
        return $this->mutate($request, 'pending_create');
    }

    public function update(InstallmentPlanSyncMutationRequest $request): JsonResponse
    {
        return $this->mutate($request, 'pending_update');
    }

    public function delete(InstallmentPlanSyncMutationRequest $request): JsonResponse
    {
        return $this->mutate($request, 'pending_delete');
    }

    private function mutate(InstallmentPlanSyncMutationRequest $request, string $operation): JsonResponse
    {
        return response()->json($this->sync->mutate(
            $request->user(),
            $request->validated('plans'),
            $operation,
        ));
    }
}
