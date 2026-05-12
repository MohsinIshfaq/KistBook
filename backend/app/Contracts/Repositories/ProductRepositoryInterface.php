<?php

namespace App\Contracts\Repositories;

use App\Models\Product;

interface ProductRepositoryInterface extends UuidRepositoryInterface
{
    public function syncCategories(Product $product, array $categoryUuids): void;
}
