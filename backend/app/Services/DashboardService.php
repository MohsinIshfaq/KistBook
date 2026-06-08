<?php

namespace App\Services;

use App\Contracts\Services\DashboardServiceInterface;
use App\Enums\InstallmentStatus;
use App\Models\Customer;
use App\Models\Installment;
use App\Models\Payment;
use App\Models\Plan;
use App\Models\Product;
use Illuminate\Support\Facades\DB;

class DashboardService implements DashboardServiceInterface
{
    public function getMetrics(): array
    {
        $pendingInstallmentAmount = (float) Installment::query()
            ->whereIn('status', [InstallmentStatus::Pending->value, InstallmentStatus::Partial->value, InstallmentStatus::Overdue->value, InstallmentStatus::Rescheduled->value])
            ->sum(DB::raw('amount - paid_amount'));

        return [
            'totalCustomers' => Customer::query()->count(),
            'totalProducts' => Product::query()->count(),
            'totalPlans' => Plan::query()->count(),
            'pendingAmount' => $pendingInstallmentAmount,
            'collectedAmount' => (float) Payment::query()->whereNull('deleted_at')->sum('amount'),
            'overdueAmount' => (float) Installment::query()->where('status', InstallmentStatus::Overdue->value)->sum(DB::raw('amount - paid_amount')),
            'paidInstallments' => Installment::query()->where('status', InstallmentStatus::Paid->value)->count(),
            'pendingInstallments' => Installment::query()->whereIn('status', [InstallmentStatus::Pending->value, InstallmentStatus::Partial->value, InstallmentStatus::Rescheduled->value])->count(),
            'overdueInstallments' => Installment::query()->where('status', InstallmentStatus::Overdue->value)->count(),
        ];
    }
}
