<?php

namespace App\Services;

use App\Contracts\Repositories\InstallmentRepositoryInterface;
use App\Contracts\Repositories\PlanRepositoryInterface;
use App\Contracts\Services\PlanServiceInterface;
use App\Models\Customer;
use App\Models\Plan;
use App\Models\Product;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class PlanService implements PlanServiceInterface
{
    public function __construct(
        private readonly PlanRepositoryInterface $plans,
        private readonly InstallmentRepositoryInterface $installments,
    ) {}

    public function list(int $perPage = 15): LengthAwarePaginator
    {
        return $this->plans->paginate($perPage, ['customer', 'product', 'installments', 'payments', 'users']);
    }

    public function create(array $data): Plan
    {
        $this->validateRelatedRecords($data);

        return DB::transaction(function () use ($data): Plan {
            /** @var Plan $plan */
            $plan = $this->plans->create($data);
            $this->generateInstallments($plan);

            return $plan->load(['customer', 'product', 'installments']);
        });
    }

    public function show(string $uuid): Plan
    {
        return $this->plans->findByUuidOrFail($uuid, ['customer', 'product', 'installments', 'payments', 'users']);
    }

    public function update(string $uuid, array $data): Plan
    {
        $plan = $this->plans->findByUuidOrFail($uuid);
        $this->validateRelatedRecords($data);

        return $this->plans->update($plan, $data)->load(['customer', 'product', 'installments', 'payments', 'users']);
    }

    private function validateRelatedRecords(array $data): void
    {
        if (isset($data['customer_uuid'])) {
            Customer::query()->where('uuid', $data['customer_uuid'])->firstOrFail();
        }

        if (isset($data['product_uuid'])) {
            Product::query()->where('uuid', $data['product_uuid'])->firstOrFail();
        }
    }

    public function delete(string $uuid): void
    {
        DB::transaction(function () use ($uuid): void {
            /** @var Plan $plan */
            $plan = $this->plans->findByUuidOrFail($uuid, ['installments']);

            foreach ($plan->installments as $installment) {
                $this->installments->softDelete($installment);
            }

            $this->plans->softDelete($plan);
        });
    }

    private function generateInstallments(Plan $plan): void
    {
        $startDate = Carbon::parse($plan->start_date);

        for ($sequence = 1; $sequence <= $plan->installment_count; $sequence++) {
            $dueDate = $startDate->copy()->addDays(($sequence - 1) * $plan->frequency_days);

            $this->installments->create([
                'company_id' => $plan->company_id,
                'plan_uuid' => $plan->uuid,
                'sequence_number' => $sequence,
                'scheduled_due_date' => $dueDate->toDateString(),
                'current_due_date' => $dueDate->toDateString(),
                'amount' => $plan->installment_amount,
                'paid_amount' => 0,
                'status' => 'pending',
                'is_deleted' => false,
            ]);
        }
    }
}
