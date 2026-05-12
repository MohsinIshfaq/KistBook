<?php

namespace App\Services;

use App\Contracts\Repositories\InstallmentRepositoryInterface;
use App\Contracts\Repositories\PaymentRepositoryInterface;
use App\Contracts\Services\PaymentServiceInterface;
use App\Models\Installment;
use App\Models\Payment;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;

class PaymentService implements PaymentServiceInterface
{
    public function __construct(
        private readonly PaymentRepositoryInterface $payments,
        private readonly InstallmentRepositoryInterface $installments,
    ) {
    }

    public function list(int $perPage = 15): LengthAwarePaginator
    {
        return $this->payments->paginate($perPage, ['customer', 'plan', 'installment', 'creator']);
    }

    public function create(array $data): Payment
    {
        $existingPayment = $this->payments->findByOperationUuid($data['operation_uuid']);

        if ($existingPayment) {
            return $existingPayment->load(['customer', 'plan', 'installment', 'creator']);
        }

        return DB::transaction(function () use ($data): Payment {
            /** @var Payment $payment */
            $payment = $this->payments->create($data);
            $this->refreshInstallmentPaidAmount($payment->installment);

            return $payment->load(['customer', 'plan', 'installment', 'creator']);
        });
    }

    public function show(string $uuid): Payment
    {
        return $this->payments->findByUuidOrFail($uuid, ['customer', 'plan', 'installment', 'creator']);
    }

    public function update(string $uuid, array $data): Payment
    {
        return DB::transaction(function () use ($uuid, $data): Payment {
            /** @var Payment $payment */
            $payment = $this->payments->findByUuidOrFail($uuid, ['installment']);
            $originalInstallment = $payment->installment;

            $payment = $this->payments->update($payment, $data);

            if ($originalInstallment) {
                $this->refreshInstallmentPaidAmount($originalInstallment->refresh());
            }

            $this->refreshInstallmentPaidAmount($payment->installment);

            return $payment->load(['customer', 'plan', 'installment', 'creator']);
        });
    }

    public function delete(string $uuid): void
    {
        DB::transaction(function () use ($uuid): void {
            /** @var Payment $payment */
            $payment = $this->payments->findByUuidOrFail($uuid, ['installment']);
            $installment = $payment->installment;

            $this->payments->softDelete($payment);

            if ($installment) {
                $this->refreshInstallmentPaidAmount($installment->refresh());
            }
        });
    }

    private function refreshInstallmentPaidAmount(?Installment $installment): void
    {
        if (! $installment) {
            return;
        }

        $paidAmount = $installment->payments()->whereNull('deleted_at')->sum('amount');
        $installment->forceFill(['paid_amount' => $paidAmount])->save();
        $this->installments->recalculateStatus($installment->refresh());
    }
}
