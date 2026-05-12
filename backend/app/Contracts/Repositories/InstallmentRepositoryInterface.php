<?php

namespace App\Contracts\Repositories;

use App\Models\Installment;

interface InstallmentRepositoryInterface extends UuidRepositoryInterface
{
    public function recalculateStatus(Installment $installment): Installment;
}
