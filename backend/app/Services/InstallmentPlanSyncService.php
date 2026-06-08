<?php

namespace App\Services;

use App\Models\Installment;
use App\Models\InstallmentPlanItem;
use App\Models\Plan;
use App\Models\User;
use App\Support\ApiKeyFormatter;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Throwable;

class InstallmentPlanSyncService
{
    public function __construct(private readonly InstallmentPlanService $plans) {}

    public function download(User $actor, ?string $lastUpdatedAt, int $limit, ?string $lastServerId = null): array
    {
        $limit = max(1, min(10, $limit));
        $query = $this->accessibleQuery($actor)
            ->where('is_deleted', false)
            ->whereIn('mode', ['common', 'separate'])
            ->with(['customer', 'items.product', 'items.variant.attributes', 'installments']);

        if ($lastUpdatedAt !== null) {
            $timestamp = Carbon::parse($lastUpdatedAt);
            $query->where(function (Builder $query) use ($timestamp, $lastServerId): void {
                $query->where('updated_at', '>', $timestamp);
                if ($lastServerId !== null) {
                    $query->orWhere(function (Builder $query) use ($timestamp, $lastServerId): void {
                        $query
                            ->where('updated_at', '=', $timestamp)
                            ->where('uuid', '>', $lastServerId);
                    });
                }
            });
        }

        $records = $query
            ->orderBy('updated_at')
            ->orderBy('uuid')
            ->limit($limit + 1)
            ->get();
        $hasMore = $records->count() > $limit;
        $records = $records->take($limit)->values();
        $lastRecord = $records->last();

        return [
            'success' => true,
            'message' => 'Installment plan sync data fetched successfully',
            'serverTime' => now()->toJSON(),
            'limit' => $limit,
            'count' => $records->count(),
            'hasMore' => $hasMore,
            'nextCursor' => $hasMore && $lastRecord instanceof Plan ? [
                'lastUpdatedAt' => $lastRecord->updated_at?->toJSON(),
                'lastServerId' => $lastRecord->uuid,
            ] : null,
            'data' => $records->map(fn (Plan $plan): array => $this->serialize($plan))->all(),
        ];
    }

    public function mutate(User $actor, array $rows, string $operation): array
    {
        if (count($rows) < 1 || count($rows) > 10) {
            throw ValidationException::withMessages([
                'plans' => ['The plans field must contain between 1 and 10 records.'],
            ]);
        }

        $mappings = [];
        $synced = [];
        $failed = [];
        $conflicts = [];

        foreach ($rows as $index => $row) {
            try {
                $result = DB::transaction(fn (): array => $this->syncRow($actor, $row, $operation));
                if (isset($result['conflict'])) {
                    $conflicts[] = ['index' => $index] + $result['conflict'];

                    continue;
                }

                $mappings[] = [
                    'index' => $index,
                    'serverId' => $result['serverId'],
                ];
                $synced[] = $result['plan'];
            } catch (ValidationException $exception) {
                $failed[] = [
                    'index' => $index,
                    'serverId' => $row['serverId'] ?? $row['server_id'] ?? null,
                    'errors' => ApiKeyFormatter::validationErrors($exception->errors()),
                ];
            } catch (Throwable $exception) {
                report($exception);
                $failed[] = [
                    'index' => $index,
                    'serverId' => $row['serverId'] ?? $row['server_id'] ?? null,
                    'errors' => ['record' => [$exception->getMessage()]],
                ];
            }
        }

        return [
            'success' => true,
            'message' => 'Installment plan sync upload completed',
            'serverTime' => now()->toJSON(),
            'mappings' => $mappings,
            'synced' => $synced,
            'failed' => $failed,
            'conflicts' => $conflicts,
        ];
    }

    private function syncRow(User $actor, array $row, string $operation): array
    {
        $row = $this->normalize($row, $operation);
        Validator::make($row, [
            'server_id' => [$operation === 'pending_create' ? 'nullable' : 'required', 'uuid'],
            'sync_status' => ['required', Rule::in(['pending_create', 'pending_update', 'pending_delete', 'synced'])],
            'updated_at' => ['nullable', 'date'],
        ])->validate();

        $plan = isset($row['server_id'])
            ? $this->accessibleQuery($actor)->withTrashed()->where('uuid', $row['server_id'])->first()
            : null;

        if ($operation !== 'pending_create' && $plan === null) {
            throw ValidationException::withMessages(['serverId' => ['The selected installment plan is unavailable.']]);
        }

        if ($plan && isset($row['updated_at']) && $plan->updated_at->greaterThan(Carbon::parse($row['updated_at']))) {
            return [
                'conflict' => [
                    'serverId' => $plan->uuid,
                    'reason' => 'The server installment plan is newer than the uploaded record.',
                    'serverRecord' => $plan->is_deleted || $plan->trashed()
                        ? $this->deletionAcknowledgement($plan)
                        : $this->serialize($this->loadPlan($plan)),
                ],
            ];
        }

        if ($operation === 'pending_delete') {
            $this->plans->delete($actor, $plan->uuid);

            return [
                'serverId' => $plan->uuid,
                'plan' => $this->deletionAcknowledgement($plan),
            ];
        }

        $data = $this->validatePlanData($actor, $row);
        $plan = $operation === 'pending_create'
            ? $this->plans->create($actor, $data)
            : $this->plans->update($actor, $plan->uuid, $data);

        return [
            'serverId' => $plan->uuid,
            'plan' => $this->serialize($this->loadPlan($plan)),
        ];
    }

    private function validatePlanData(User $actor, array $row): array
    {
        $data = Validator::make($row, [
            'customer_uuid' => ['required', 'uuid'],
            'mode' => ['required', Rule::in(['common', 'separate'])],
            'selected_products' => ['required', 'array', 'min:1'],
            'selected_products.*.uuid' => ['nullable', 'uuid'],
            'selected_products.*.product_uuid' => ['required', 'uuid'],
            'selected_products.*.variant_uuid' => ['nullable', 'uuid'],
            'selected_products.*.quantity' => ['required', 'integer', 'min:1'],
            'selected_products.*.agreed_price' => ['nullable', 'numeric', 'min:0'],
            'selected_products.*.deposit' => ['nullable', 'numeric', 'min:0'],
            'selected_products.*.installment_amount' => ['nullable', 'numeric', 'gt:0'],
            'selected_products.*.frequency_days' => ['nullable', 'integer', 'min:1'],
            'selected_products.*.first_due_date' => ['nullable', 'date'],
            'common_deposit' => ['nullable', 'numeric', 'min:0'],
            'common_installment_amount' => ['nullable', 'numeric', 'gt:0'],
            'common_frequency_days' => ['nullable', 'integer', 'min:1'],
            'common_first_due_date' => ['nullable', 'date'],
            'notes' => ['nullable', 'string'],
            'status' => ['nullable', Rule::in(['active', 'completed', 'cancelled'])],
        ])->after(function ($validator) use ($row): void {
            if (($row['mode'] ?? 'common') === 'common') {
                foreach (['common_installment_amount', 'common_frequency_days', 'common_first_due_date'] as $field) {
                    if (! isset($row[$field]) || $row[$field] === '') {
                        $validator->errors()->add($field, 'This field is required for common plans.');
                    }
                }

                return;
            }

            foreach ($row['selected_products'] ?? [] as $index => $product) {
                foreach (['installment_amount', 'frequency_days', 'first_due_date'] as $field) {
                    if (! isset($product[$field]) || $product[$field] === '') {
                        $validator->errors()->add("selectedProducts.$index.$field", 'This field is required for separate plans.');
                    }
                }
            }
        })->validate();

        return $data + ['status' => $row['status'] ?? 'active'];
    }

    private function normalize(array $row, string $operation): array
    {
        return array_filter([
            'server_id' => $row['serverId'] ?? $row['server_id'] ?? $row['id'] ?? null,
            'sync_status' => $operation,
            'updated_at' => $row['updatedAt'] ?? $row['updated_at'] ?? null,
            'customer_uuid' => $row['customerId'] ?? $row['customer_uuid'] ?? null,
            'mode' => $row['mode'] ?? 'common',
            'selected_products' => $this->normalizeProducts($row['selectedProducts'] ?? $row['selected_products'] ?? []),
            'common_deposit' => $row['commonDeposit'] ?? $row['common_deposit'] ?? $row['deposit'] ?? null,
            'common_installment_amount' => $row['commonInstallmentAmount'] ?? $row['common_installment_amount'] ?? $row['installmentAmount'] ?? null,
            'common_frequency_days' => $row['commonFrequencyInDays'] ?? $row['common_frequency_days'] ?? $row['frequencyInDays'] ?? null,
            'common_first_due_date' => $row['commonFirstDueDate'] ?? $row['common_first_due_date'] ?? $row['firstDueDate'] ?? null,
            'notes' => $row['note'] ?? $row['notes'] ?? null,
            'status' => $row['status'] ?? null,
        ], fn (mixed $value): bool => $value !== null);
    }

    private function normalizeProducts(mixed $products): mixed
    {
        if (! is_array($products)) {
            return $products;
        }

        return array_map(fn (mixed $product): mixed => is_array($product) ? array_filter([
            'uuid' => $product['serverId'] ?? $product['uuid'] ?? null,
            'product_uuid' => $product['productId'] ?? $product['product_uuid'] ?? null,
            'variant_uuid' => $product['variantId'] ?? $product['variant_uuid'] ?? null,
            'quantity' => $product['quantity'] ?? 1,
            'agreed_price' => $product['agreedPrice'] ?? $product['agreed_price'] ?? null,
            'deposit' => $product['deposit'] ?? null,
            'installment_amount' => $product['installmentAmount'] ?? $product['installment_amount'] ?? null,
            'frequency_days' => $product['frequencyInDays'] ?? $product['frequency_days'] ?? null,
            'first_due_date' => $product['firstDueDate'] ?? $product['first_due_date'] ?? null,
        ], fn (mixed $value): bool => $value !== null) : $product, $products);
    }

    private function accessibleQuery(User $actor): Builder
    {
        return Plan::query()
            ->when($actor->isSalesman(), function (Builder $query) use ($actor): void {
                $query->whereHas('users', function (Builder $query) use ($actor): void {
                    $query
                        ->where('users.uuid', $actor->uuid)
                        ->where('user_plan_access.is_deleted', false);
                });
            });
    }

    private function loadPlan(Plan $plan): Plan
    {
        return $plan->load(['customer', 'items.product', 'items.variant.attributes', 'installments']);
    }

    private function deletionAcknowledgement(Plan $plan): array
    {
        return [
            'serverId' => $plan->uuid,
            'isSync' => true,
            'syncStatus' => 'synced',
            'isDeleted' => true,
        ];
    }

    public function serialize(Plan $plan): array
    {
        return [
            'serverId' => $plan->uuid,
            'customerId' => $plan->customer_uuid,
            'mode' => $plan->mode,
            'selectedProducts' => $plan->items
                ->map(fn (InstallmentPlanItem $item): array => [
                    'serverId' => $item->uuid,
                    'productId' => $item->product_uuid,
                    'variantId' => $item->variant_uuid,
                    'quantity' => $item->quantity,
                    'agreedPrice' => (float) $item->unit_price_snapshot,
                    'totalAmount' => (float) $item->total_amount,
                    'deposit' => (float) $item->deposit_amount,
                    'installmentAmount' => (float) $item->installment_amount,
                    'frequencyInDays' => $item->frequency_days,
                    'firstDueDate' => $item->first_due_date?->toDateString(),
                    'itemName' => $item->item_name,
                ])
                ->values()
                ->all(),
            'commonDeposit' => (float) $plan->deposit_amount,
            'commonInstallmentAmount' => (float) $plan->installment_amount,
            'commonFrequencyInDays' => $plan->frequency_days,
            'commonFirstDueDate' => $plan->start_date?->toDateString(),
            'totalAmount' => (float) $plan->total_amount,
            'remainingAmount' => (float) $plan->remaining_amount,
            'installmentCount' => $plan->installment_count,
            'note' => $plan->notes,
            'status' => $plan->status?->value ?? $plan->status,
            'schedules' => $plan->installments
                ->sortBy(['sequence_number', 'uuid'])
                ->map(fn (Installment $schedule): array => [
                    'serverId' => $schedule->uuid,
                    'planId' => $schedule->plan_uuid,
                    'planItemId' => $schedule->plan_item_uuid,
                    'scheduleGroup' => $schedule->schedule_group,
                    'sequenceNumber' => $schedule->sequence_number,
                    'itemSequenceNumber' => $schedule->item_sequence_number,
                    'scheduledDueDate' => $schedule->scheduled_due_date?->toJSON(),
                    'currentDueDate' => $schedule->current_due_date?->toJSON(),
                    'previousDueDate' => $schedule->previous_due_date?->toJSON(),
                    'amount' => (float) $schedule->amount,
                    'paidAmount' => (float) $schedule->paid_amount,
                    'status' => $schedule->status?->value ?? $schedule->status,
                    'rescheduleNote' => $schedule->reschedule_note,
                    'rescheduledAt' => $schedule->rescheduled_at?->toJSON(),
                    'isDeleted' => (bool) $schedule->is_deleted,
                    'createdAt' => $schedule->created_at?->toJSON(),
                    'updatedAt' => $schedule->updated_at?->toJSON(),
                ])
                ->values()
                ->all(),
            'isSync' => true,
            'syncStatus' => 'synced',
            'isDeleted' => false,
            'createdAt' => $plan->created_at?->toJSON(),
            'updatedAt' => $plan->updated_at?->toJSON(),
        ];
    }
}
