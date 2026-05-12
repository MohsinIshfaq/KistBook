<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Services\ProductServiceInterface;
use App\Http\Controllers\Controller;
use App\Http\Requests\Products\StoreProductRequest;
use App\Http\Requests\Products\UpdateProductRequest;
use App\Http\Resources\ProductResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function __construct(private readonly ProductServiceInterface $products)
    {
    }

    public function index(Request $request): JsonResponse
    {
        return $this->successResponse(ProductResource::collection($this->products->list((int) $request->integer('per_page', 15))));
    }

    public function store(StoreProductRequest $request): JsonResponse
    {
        return $this->successResponse(new ProductResource($this->products->create($request->validated())), 'Product created successfully.', 201);
    }

    public function show(string $uuid): JsonResponse
    {
        return $this->successResponse(new ProductResource($this->products->show($uuid)));
    }

    public function update(UpdateProductRequest $request, string $uuid): JsonResponse
    {
        return $this->successResponse(new ProductResource($this->products->update($uuid, $request->validated())), 'Product updated successfully.');
    }

    public function destroy(string $uuid): JsonResponse
    {
        $this->products->delete($uuid);

        return $this->successResponse(null, 'Product deleted successfully.');
    }
}
