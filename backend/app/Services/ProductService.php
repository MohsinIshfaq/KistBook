<?php

namespace App\Services;

use App\Contracts\Repositories\ProductRepositoryInterface;
use App\Contracts\Services\ProductServiceInterface;
use App\Models\Product;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;

class ProductService implements ProductServiceInterface
{
    public function __construct(private readonly ProductRepositoryInterface $products)
    {
    }

    public function list(int $perPage = 15): LengthAwarePaginator
    {
        return $this->products->paginate($perPage, ['categories']);
    }

    public function create(array $data): Product
    {
        return DB::transaction(function () use ($data): Product {
            $categoryUuids = $data['category_uuids'] ?? [];
            unset($data['category_uuids']);

            /** @var Product $product */
            $product = $this->products->create($data);
            $this->products->syncCategories($product, $categoryUuids);

            return $product->load('categories');
        });
    }

    public function show(string $uuid): Product
    {
        return $this->products->findByUuidOrFail($uuid, ['categories', 'plans']);
    }

    public function update(string $uuid, array $data): Product
    {
        return DB::transaction(function () use ($uuid, $data): Product {
            $product = $this->products->findByUuidOrFail($uuid);
            $categoryUuids = $data['category_uuids'] ?? null;
            unset($data['category_uuids']);

            /** @var Product $updated */
            $updated = $this->products->update($product, $data);

            if (is_array($categoryUuids)) {
                $this->products->syncCategories($updated, $categoryUuids);
            }

            return $updated->load('categories');
        });
    }

    public function delete(string $uuid): void
    {
        $product = $this->products->findByUuidOrFail($uuid);
        $this->products->softDelete($product);
    }
}
