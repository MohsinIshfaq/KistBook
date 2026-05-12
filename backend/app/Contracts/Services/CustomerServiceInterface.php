<?php

namespace App\Contracts\Services;

use App\Models\Customer;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

interface CustomerServiceInterface
{
    public function list(int $perPage = 15): LengthAwarePaginator;

    public function create(array $data): Customer;

    public function show(string $uuid): Customer;

    public function update(string $uuid, array $data): Customer;

    public function delete(string $uuid): void;
}
