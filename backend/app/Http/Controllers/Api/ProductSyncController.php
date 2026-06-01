<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Products\ProductSyncMutationRequest;
use App\Services\ProductSyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductSyncController extends Controller
{
    public function __construct(private readonly ProductSyncService $sync) {}

    public function download(Request $request): JsonResponse
    {
        $maxLimit = max(1, min(10, (int) config('kistbook.product_sync.max_limit', 10)));
        $validated = $request->validate([
            'lastUpdatedAt' => ['nullable', 'date', 'required_with:lastServerId'],
            'lastServerId' => ['nullable', 'uuid'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:'.$maxLimit],
        ]);

        return response()->json($this->sync->download(
            $validated['lastUpdatedAt'] ?? null,
            (int) ($validated['limit'] ?? min($maxLimit, max(1, (int) config('kistbook.product_sync.default_limit', 10)))),
            $validated['lastServerId'] ?? null,
        ));
    }

    public function create(ProductSyncMutationRequest $request): JsonResponse
    {
        return $this->mutate($request, 'pending_create');
    }

    public function update(ProductSyncMutationRequest $request): JsonResponse
    {
        return $this->mutate($request, 'pending_update');
    }

    public function delete(ProductSyncMutationRequest $request): JsonResponse
    {
        return $this->mutate($request, 'pending_delete');
    }

    private function mutate(ProductSyncMutationRequest $request, string $operation): JsonResponse
    {
        return response()->json($this->sync->mutate(
            $request->user(),
            $request->validated('products'),
            $operation,
        ));
    }
}
