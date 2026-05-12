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
            ->whereIn('status', [InstallmentStatus::Pending->value, InstallmentStatus::Partial->value, InstallmentStatus::Overdue->value])
            ->sum(DB::raw('amount - paid_amount'));

        return [
            'total_customers' => Customer::query()->count(),
            'total_products' => Product::query()->count(),
            'total_plans' => Plan::query()->count(),
            'pending_amount' => $pendingInstallmentAmount,
            'collected_amount' => (float) Payment::query()->whereNull('deleted_at')->sum('amount'),
            'overdue_amount' => (float) Installment::query()->where('status', InstallmentStatus::Overdue->value)->sum(DB::raw('amount - paid_amount')),
            'paid_installments' => Installment::query()->where('status', InstallmentStatus::Paid->value)->count(),
            'pending_installments' => Installment::query()->whereIn('status', [InstallmentStatus::Pending->value, InstallmentStatus::Partial->value])->count(),
            'overdue_installments' => Installment::query()->where('status', InstallmentStatus::Overdue->value)->count(),
        ];
    }
}
