<?php

namespace App\Services;

use App\Contracts\Repositories\InstallmentRepositoryInterface;
use App\Contracts\Services\InstallmentServiceInterface;
use App\Models\Installment;
use App\Models\Plan;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class InstallmentService implements InstallmentServiceInterface
{
    public function __construct(private readonly InstallmentRepositoryInterface $installments) {}

    public function list(int $perPage = 15): LengthAwarePaginator
    {
        return $this->installments->paginate($perPage, ['plan.customer', 'payments']);
    }

    public function create(array $data): Installment
    {
        $this->validatePlan($data);

        /** @var Installment $installment */
        $installment = $this->installments->create($data);

        return $this->installments->recalculateStatus($installment)->load(['plan.customer', 'payments']);
    }

    public function show(string $uuid): Installment
    {
        return $this->installments->findByUuidOrFail($uuid, ['plan.customer', 'payments']);
    }

    public function update(string $uuid, array $data): Installment
    {
        /** @var Installment $installment */
        $installment = $this->installments->findByUuidOrFail($uuid);
        $this->validatePlan($data);
        $installment = $this->installments->update($installment, $data);

        return $this->installments->recalculateStatus($installment)->load(['plan.customer', 'payments']);
    }

    private function validatePlan(array $data): void
    {
        if (isset($data['plan_uuid'])) {
            Plan::query()->where('uuid', $data['plan_uuid'])->firstOrFail();
        }
    }

    public function delete(string $uuid): void
    {
        $installment = $this->installments->findByUuidOrFail($uuid);
        $this->installments->softDelete($installment);
    }
}
