<?php

namespace App\Repositories;

use App\Contracts\Repositories\PaymentRepositoryInterface;
use App\Models\Payment;

class PaymentRepository extends BaseRepository implements PaymentRepositoryInterface
{
    public function __construct(Payment $payment)
    {
        parent::__construct($payment);
    }

    public function findByOperationUuid(string $operationUuid): ?Payment
    {
        return Payment::query()->where('operation_uuid', $operationUuid)->first();
    }
}
