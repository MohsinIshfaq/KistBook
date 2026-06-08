<?php

namespace App\Repositories;

use App\Contracts\Repositories\InstallmentRepositoryInterface;
use App\Enums\InstallmentStatus;
use App\Models\Installment;

class InstallmentRepository extends BaseRepository implements InstallmentRepositoryInterface
{
    public function __construct(Installment $installment)
    {
        parent::__construct($installment);
    }

    public function recalculateStatus(Installment $installment): Installment
    {
        $paidAmount = (float) $installment->paid_amount;
        $amount = (float) $installment->amount;
        $today = now()->startOfDay();

        $status = InstallmentStatus::Pending;

        if ($paidAmount >= $amount) {
            $status = InstallmentStatus::Paid;
        } elseif ($paidAmount > 0) {
            $status = InstallmentStatus::Partial;
        } elseif ($installment->current_due_date->isBefore($today)) {
            $status = InstallmentStatus::Overdue;
        } elseif ($installment->status === InstallmentStatus::Rescheduled) {
            $status = InstallmentStatus::Rescheduled;
        }

        $installment->forceFill(['status' => $status->value])->save();

        return $installment->refresh();
    }
}
