<?php

namespace App\Contracts\Repositories;

use App\Models\Product;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

interface ProductRepositoryInterface extends UuidRepositoryInterface
{
    public function paginateSearch(int $perPage = 15, ?string $search = null, array $with = []): LengthAwarePaginator;

    public function syncCategories(Product $product, array $categoryUuids): void;
}
