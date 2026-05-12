<?php

namespace App\Contracts\Services;

use App\Models\Installment;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

interface InstallmentServiceInterface
{
    public function list(int $perPage = 15): LengthAwarePaginator;

    public function create(array $data): Installment;

    public function show(string $uuid): Installment;

    public function update(string $uuid, array $data): Installment;

    public function delete(string $uuid): void;
}
