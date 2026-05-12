<?php

namespace App\Contracts\Services;

use App\Models\ProductCategory;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

interface ProductCategoryServiceInterface
{
    public function list(int $perPage = 15): LengthAwarePaginator;

    public function create(array $data): ProductCategory;

    public function show(string $uuid): ProductCategory;

    public function update(string $uuid, array $data): ProductCategory;

    public function delete(string $uuid): void;
}
