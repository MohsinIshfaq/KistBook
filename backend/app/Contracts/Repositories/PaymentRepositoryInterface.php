<?php

namespace App\Contracts\Repositories;

use App\Models\Payment;

interface PaymentRepositoryInterface extends UuidRepositoryInterface
{
    public function findByOperationUuid(string $operationUuid): ?Payment;
}
