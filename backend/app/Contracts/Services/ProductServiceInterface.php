<?php

namespace App\Contracts\Services;

use App\Models\Product;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

interface ProductServiceInterface
{
    public function list(int $perPage = 15): LengthAwarePaginator;

    public function create(array $data): Product;

    public function show(string $uuid): Product;

    public function update(string $uuid, array $data): Product;

    public function delete(string $uuid): void;
}
