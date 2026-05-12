<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Services\ProductCategoryServiceInterface;
use App\Http\Controllers\Controller;
use App\Http\Requests\Categories\StoreCategoryRequest;
use App\Http\Requests\Categories\UpdateCategoryRequest;
use App\Http\Resources\ProductCategoryResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CategoryController extends Controller
{
    public function __construct(private readonly ProductCategoryServiceInterface $categories)
    {
    }

    public function index(Request $request): JsonResponse
    {
        return $this->successResponse(ProductCategoryResource::collection($this->categories->list((int) $request->integer('per_page', 15))));
    }

    public function store(StoreCategoryRequest $request): JsonResponse
    {
        return $this->successResponse(new ProductCategoryResource($this->categories->create($request->validated())), 'Category created successfully.', 201);
    }

    public function show(string $uuid): JsonResponse
    {
        return $this->successResponse(new ProductCategoryResource($this->categories->show($uuid)));
    }

    public function update(UpdateCategoryRequest $request, string $uuid): JsonResponse
    {
        return $this->successResponse(new ProductCategoryResource($this->categories->update($uuid, $request->validated())), 'Category updated successfully.');
    }

    public function destroy(string $uuid): JsonResponse
    {
        $this->categories->delete($uuid);

        return $this->successResponse(null, 'Category deleted successfully.');
    }
}
