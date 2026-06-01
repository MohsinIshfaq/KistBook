<?php

namespace App\Services;

use App\Contracts\Repositories\CustomerRepositoryInterface;
use App\Contracts\Repositories\UserPlanAccessRepositoryInterface;
use App\Models\InstallmentPlanItem;
use App\Models\Plan;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class InstallmentPlanService
{
    public function __construct(
        private readonly CustomerRepositoryInterface $customers,
        private readonly InstallmentScheduleService $schedules,
        private readonly UserPlanAccessRepositoryInterface $planAccess,
    ) {}

    public function list(User $actor, int $perPage, ?string $search): LengthAwarePaginator
    {
        return $this->accessibleQuery($actor)
            ->with(['customer', 'items.product', 'items.variant.attributes', 'installments'])
            ->when($search, fn ($query, string $search) => $query->whereHas('customer', fn ($query) => $query->where('name', 'like', '%'.$search.'%')))
            ->latest()
            ->paginate($perPage);
    }

    public function show(User $actor, string $uuid): Plan
    {
        return $this->accessibleQuery($actor)
            ->with(['customer', 'items.product.images', 'items.variant.attributes', 'items.schedules', 'installments'])
            ->where('uuid', $uuid)
            ->firstOrFail();
    }

    public function create(User $actor, array $data): Plan
    {
        $this->customers->findAccessibleByUuidOrFail($actor, $data['customer_uuid']);

        return DB::transaction(function () use ($actor, $data): Plan {
            $items = $this->buildItems($data);
            $plan = Plan::query()->create($this->planData($actor, $data, $items));
            foreach ($items as $item) {
                $plan->items()->create($item);
            }
            if ($actor->isSalesman()) {
                $this->planAccess->assign($actor->uuid, $plan->uuid);
            }
            $this->schedules->rebuild($plan->refresh());

            return $this->show($actor, $plan->uuid);
        });
    }

    public function update(User $actor, string $uuid, array $data): Plan
    {
        $plan = $this->show($actor, $uuid);
        $this->customers->findAccessibleByUuidOrFail($actor, $data['customer_uuid']);

        return DB::transaction(function () use ($actor, $plan, $data): Plan {
            $hasPayments = $plan->installments()->where('paid_amount', '>', 0)->exists();
            if ($hasPayments && $plan->mode !== $data['mode']) {
                throw ValidationException::withMessages(['mode' => ['Plan mode cannot be changed after a payment has been recorded.']]);
            }

            $items = $this->buildItems($data);
            $kept = [];
            foreach ($items as $itemData) {
                $item = isset($itemData['uuid'])
                    ? $plan->items()->withTrashed()->where('uuid', $itemData['uuid'])->first()
                    : $plan->items()->where('product_uuid', $itemData['product_uuid'])->where('variant_uuid', $itemData['variant_uuid'])->first();
                if (isset($itemData['uuid']) && $item === null) {
                    throw ValidationException::withMessages(['selectedProducts' => ['The selected plan item does not belong to this plan.']]);
                }
                unset($itemData['uuid']);
                $item ??= new InstallmentPlanItem(['plan_uuid' => $plan->uuid]);
                if ($item->trashed()) {
                    $item->restore();
                }
                $item->fill($itemData + ['plan_uuid' => $plan->uuid, 'is_deleted' => false])->save();
                $kept[] = $item->uuid;
            }

            foreach ($plan->items()->whereNotIn('uuid', $kept)->get() as $item) {
                if ($item->schedules()->where('paid_amount', '>', 0)->exists()) {
                    throw ValidationException::withMessages(['selectedProducts' => ['Products with paid installments cannot be removed.']]);
                }
                $item->forceFill(['is_deleted' => true])->save();
                $item->delete();
            }

            $plan->fill($this->planData($actor, $data, $items))->save();
            $this->schedules->rebuild($plan->refresh());

            return $this->show($actor, $plan->uuid);
        });
    }

    public function delete(User $actor, string $uuid): void
    {
        $plan = $this->show($actor, $uuid);
        DB::transaction(function () use ($plan): void {
            foreach ($plan->installments as $schedule) {
                $schedule->forceFill(['is_deleted' => true])->save();
                $schedule->delete();
            }
            foreach ($plan->items as $item) {
                $item->forceFill(['is_deleted' => true])->save();
                $item->delete();
            }
            $plan->forceFill(['is_deleted' => true])->save();
            $plan->delete();
        });
    }

    private function buildItems(array $data): array
    {
        return collect($data['selected_products'])->map(function (array $selected) use ($data): array {
            $product = Product::query()->where('uuid', $selected['product_uuid'])->firstOrFail();
            $variant = isset($selected['variant_uuid'])
                ? ProductVariant::query()->where('uuid', $selected['variant_uuid'])->where('product_uuid', $product->uuid)->firstOrFail()
                : null;
            $price = (float) ($selected['agreed_price'] ?? $variant?->sale_price ?? $product->base_price ?? $product->sales_price);
            $quantity = (int) $selected['quantity'];
            $separate = $data['mode'] === 'separate';

            return [
                'uuid' => $selected['uuid'] ?? null,
                'product_uuid' => $product->uuid,
                'variant_uuid' => $variant?->uuid,
                'quantity' => $quantity,
                'unit_price_snapshot' => $price,
                'total_amount' => $price * $quantity,
                'deposit_amount' => $separate ? (float) ($selected['deposit'] ?? 0) : 0,
                'installment_amount' => $separate ? (float) $selected['installment_amount'] : (float) $data['common_installment_amount'],
                'frequency_days' => $separate ? (int) $selected['frequency_days'] : (int) $data['common_frequency_days'],
                'first_due_date' => $separate ? $selected['first_due_date'] : $data['common_first_due_date'],
                'item_name' => $product->product_name,
                'is_deleted' => false,
            ];
        })->all();
    }

    private function planData(User $actor, array $data, array $items): array
    {
        $total = (float) collect($items)->sum('total_amount');
        $deposit = $data['mode'] === 'common'
            ? (float) ($data['common_deposit'] ?? 0)
            : (float) collect($items)->sum('deposit_amount');
        if ($deposit > $total) {
            throw ValidationException::withMessages(['deposit' => ['Deposit cannot exceed the plan total.']]);
        }

        $first = $items[0];

        return [
            'company_id' => $actor->company_id,
            'customer_uuid' => $data['customer_uuid'],
            'product_uuid' => $first['product_uuid'],
            'mode' => $data['mode'],
            'quantity' => (int) collect($items)->sum('quantity'),
            'unit_price' => $total / max(1, (int) collect($items)->sum('quantity')),
            'total_amount' => $total,
            'deposit_amount' => $deposit,
            'remaining_amount' => $total - $deposit,
            'installment_amount' => $data['mode'] === 'common' ? $data['common_installment_amount'] : $first['installment_amount'],
            'installment_count' => 0,
            'frequency_days' => $data['mode'] === 'common' ? $data['common_frequency_days'] : $first['frequency_days'],
            'start_date' => $data['mode'] === 'common' ? $data['common_first_due_date'] : $first['first_due_date'],
            'notes' => $data['notes'] ?? null,
            'status' => $data['status'] ?? 'active',
            'is_deleted' => false,
        ];
    }

    private function accessibleQuery(User $actor)
    {
        return Plan::query()
            ->whereIn('mode', ['common', 'separate'])
            ->when($actor->isSalesman(), fn ($query) => $query->whereHas('users', fn ($query) => $query->where('users.uuid', $actor->uuid)->where('user_plan_access.is_deleted', false)));
    }
}
