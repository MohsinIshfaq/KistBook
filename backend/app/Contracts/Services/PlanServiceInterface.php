<?php

namespace App\Contracts\Services;

use App\Models\Plan;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

interface PlanServiceInterface
{
    public function list(int $perPage = 15): LengthAwarePaginator;

    public function create(array $data): Plan;

    public function show(string $uuid): Plan;

    public function update(string $uuid, array $data): Plan;

    public function delete(string $uuid): void;
}
