<?php

namespace App\Contracts\Services;

use App\Models\Payment;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

interface PaymentServiceInterface
{
    public function list(int $perPage = 15): LengthAwarePaginator;

    public function create(array $data): Payment;

    public function show(string $uuid): Payment;

    public function update(string $uuid, array $data): Payment;

    public function delete(string $uuid): void;
}
