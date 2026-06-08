<?php

namespace App\Services;

use App\Contracts\Repositories\CustomerRepositoryInterface;
use App\Models\InstallmentPlanItem;
use App\Models\Plan;
use App\Models\Product;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Gate;

class CustomerPlanDetailService
{
    public function __construct(
        private readonly CustomerRepositoryInterface $customers,
        private readonly ProductSyncService $products,
        private readonly InstallmentPlanSyncService $plans,
    ) {}

    public function show(User $actor, string $customerUuid): array
    {
        $customer = $this->customers->findAccessibleByUuidOrFail($actor, $customerUuid);
        Gate::forUser($actor)->authorize('view', $customer);

        $plans = Plan::query()
            ->where('customer_uuid', $customer->uuid)
            ->where('is_deleted', false)
            ->whereIn('mode', ['common', 'separate'])
            ->with([
                'customer',
                'items.product.categories',
                'items.product.images',
                'items.product.variants.attributes',
                'items.product.priceHistory',
                'items.variant.attributes',
                'installments',
            ])
            ->when($actor->isSalesman(), function (Builder $query) use ($actor): void {
                $query->where(function (Builder $query) use ($actor): void {
                    $query
                        ->whereHas('users', function (Builder $query) use ($actor): void {
                            $query
                                ->where('users.uuid', $actor->uuid)
                                ->where('user_plan_access.is_deleted', false);
                        })
                        ->orWhereHas('customer.users', function (Builder $query) use ($actor): void {
                            $query
                                ->where('users.uuid', $actor->uuid)
                                ->where('user_customer_access.is_deleted', false);
                        });
                });
            })
            ->latest()
            ->get();

        $products = $plans
            ->flatMap(fn (Plan $plan) => $plan->items->map(
                fn (InstallmentPlanItem $item): ?Product => $item->product,
            ))
            ->filter()
            ->unique('uuid')
            ->values();

        return [
            'customerId' => $customer->uuid,
            'products' => $products
                ->map(fn (Product $product): array => $this->products->serialize($product))
                ->all(),
            'plans' => $plans
                ->map(fn (Plan $plan): array => $this->plans->serialize($plan))
                ->all(),
        ];
    }
}
