<?php

namespace App\Services;

use App\Contracts\Repositories\ProductCategoryRepositoryInterface;
use App\Contracts\Services\ProductCategoryServiceInterface;
use App\Models\ProductCategory;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class ProductCategoryService implements ProductCategoryServiceInterface
{
    public function __construct(private readonly ProductCategoryRepositoryInterface $categories)
    {
    }

    public function list(int $perPage = 15): LengthAwarePaginator
    {
        return $this->categories->paginate($perPage, ['products']);
    }

    public function create(array $data): ProductCategory
    {
        return $this->categories->create($data);
    }

    public function show(string $uuid): ProductCategory
    {
        return $this->categories->findByUuidOrFail($uuid, ['products']);
    }

    public function update(string $uuid, array $data): ProductCategory
    {
        $category = $this->categories->findByUuidOrFail($uuid);

        return $this->categories->update($category, $data);
    }

    public function delete(string $uuid): void
    {
        $category = $this->categories->findByUuidOrFail($uuid);
        $this->categories->softDelete($category);
    }
}
