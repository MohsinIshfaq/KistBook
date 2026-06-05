<?php

namespace App\Services;

use App\Contracts\Repositories\UserCustomerAccessRepositoryInterface;
use App\Models\Customer;
use App\Models\CustomerSyncMapping;
use App\Models\User;
use App\Support\ApiKeyFormatter;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Throwable;

class CustomerSyncService
{
    public function __construct(
        private readonly CustomerImageStorageService $images,
        private readonly UserCustomerAccessRepositoryInterface $customerAccess,
    ) {}

    public function download(User $actor, ?string $lastUpdatedAt, int $limit, ?string $lastServerId = null): array
    {
        $limit = max(1, min(10, $limit));
        $query = $this->accessibleQuery($actor)->where('is_deleted', false);
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
            'message' => 'Customer sync data fetched successfully',
            'serverTime' => now()->toJSON(),
            'limit' => $limit,
            'count' => $records->count(),
            'hasMore' => $hasMore,
            'nextCursor' => $hasMore && $lastRecord instanceof Customer ? [
                'lastUpdatedAt' => $lastRecord->updated_at?->toJSON(),
                'lastServerId' => $lastRecord->uuid,
            ] : null,
            'data' => $records->map(fn (Customer $customer): array => $this->serialize($customer))->all(),
        ];
    }

    public function upload(User $actor, ?string $deviceId, array $rows, ?string $operation = null): array
    {
        if (count($rows) < 1 || count($rows) > 10) {
            throw ValidationException::withMessages([
                'customers' => ['The customers field must contain between 1 and 10 records.'],
            ]);
        }

        $mappings = [];
        $synced = [];
        $failed = [];
        $conflicts = [];

        foreach ($rows as $index => $row) {
            try {
                $result = DB::transaction(fn (): array => $this->syncRow($actor, $deviceId, $row, $operation));
                if (isset($result['conflict'])) {
                    $conflicts[] = $result['conflict'];

                    continue;
                }

                $mappings[] = ['index' => $index] + $result['mapping'];
                $synced[] = $result['customer'];
            } catch (ValidationException $exception) {
                $failed[] = [
                    'index' => $index,
                    'localId' => $row['localId'] ?? $row['local_id'] ?? null,
                    'errors' => ApiKeyFormatter::validationErrors($exception->errors()),
                ];
            } catch (Throwable $exception) {
                report($exception);
                $failed[] = [
                    'index' => $index,
                    'localId' => $row['localId'] ?? $row['local_id'] ?? null,
                    'errors' => ['record' => [$exception->getMessage()]],
                ];
            }
        }

        return [
            'success' => true,
            'message' => 'Customer sync upload completed',
            'serverTime' => now()->toJSON(),
            'mappings' => $mappings,
            'synced' => $synced,
            'failed' => $failed,
            'conflicts' => $conflicts,
        ];
    }

    private function syncRow(User $actor, ?string $deviceId, array $row, ?string $operation): array
    {
        $row = $this->normalize($row, $operation);
        Validator::make($row, [
            'local_id' => ['nullable', 'string', 'max:191'],
            'server_id' => ['nullable', 'uuid'],
            'sync_status' => ['required', Rule::in(['pending_create', 'pending_update', 'pending_delete', 'synced'])],
            'updated_at' => ['nullable', 'date'],
        ])->validate();

        $mapping = $deviceId !== null && $row['local_id'] !== null
            ? CustomerSyncMapping::query()
                ->where('company_id', $actor->company_id)
                ->where('user_id', $actor->id)
                ->where('device_id', $deviceId)
                ->where('local_id', $row['local_id'])
                ->first()
            : null;
        $serverId = $row['server_id'] ?? $mapping?->customer_uuid;
        $customer = $serverId
            ? $this->accessibleQuery($actor)->withTrashed()->where('uuid', $serverId)->first()
            : null;

        if ($serverId && $customer === null) {
            throw ValidationException::withMessages(['serverId' => ['The selected customer is unavailable.']]);
        }

        if ($customer && isset($row['updated_at']) && $customer->updated_at->greaterThan(Carbon::parse($row['updated_at']))) {
            return [
                'conflict' => [
                    'localId' => $row['local_id'],
                    'serverId' => $customer->uuid,
                    'reason' => 'The server customer is newer than the uploaded record.',
                    'serverRecord' => $customer->is_deleted || $customer->trashed()
                        ? $this->deletionAcknowledgement($row['local_id'], $customer)
                        : $this->serialize($customer),
                ],
            ];
        }

        if ($row['sync_status'] === 'pending_delete') {
            if ($customer === null) {
                throw ValidationException::withMessages(['serverId' => ['A server customer is required for pending_delete.']]);
            }

            if ($customer) {
                Gate::forUser($actor)->authorize('delete', $customer);
                $customer->forceFill(['is_deleted' => true])->save();
                if (! $customer->trashed()) {
                    $customer->delete();
                }
            }

            return $this->result($actor, $deviceId, $row['local_id'], $customer);
        }

        if ($customer === null && $row['sync_status'] === 'pending_update') {
            throw ValidationException::withMessages(['serverId' => ['A server customer is required for pending_update.']]);
        }

        $rules = [
            'card_no' => [$customer ? 'sometimes' : 'required', 'string', 'max:50', Rule::unique('customers', 'card_no')->where('company_id', $actor->company_id)->ignore($customer?->uuid, 'uuid')],
            'name' => [$customer ? 'sometimes' : 'required', 'string', 'max:255'],
            'phone' => [$customer ? 'sometimes' : 'required', 'string', 'max:20'],
            'cnic' => [$customer ? 'sometimes' : 'required', 'string', 'max:50', Rule::unique('customers', 'cnic')->where('company_id', $actor->company_id)->ignore($customer?->uuid, 'uuid')],
            'address' => ['nullable', 'string'],
            'reference' => ['nullable', 'string', 'max:255'],
            'customer_image_base64' => ['nullable', 'string'],
            'customer_image_original_name' => ['nullable', 'string', 'max:255'],
            'customer_image_mime_type' => ['nullable', 'string', 'max:100'],
            'remove_customer_image' => ['nullable', 'boolean'],
        ];
        $data = Validator::make($row, $rules)->validate();
        $imageBase64 = $data['customer_image_base64'] ?? null;
        $removeImage = (bool) ($data['remove_customer_image'] ?? false);
        unset($data['customer_image_base64'], $data['customer_image_original_name'], $data['customer_image_mime_type'], $data['remove_customer_image']);

        if ($customer === null) {
            Gate::forUser($actor)->authorize('create', Customer::class);
            $customer = Customer::query()->create($data + ['company_id' => $actor->company_id]);
            if ($actor->isSalesman()) {
                $this->customerAccess->assign($actor->uuid, $customer->uuid);
            }
        } else {
            Gate::forUser($actor)->authorize('update', $customer);
            $customer->fill($data)->save();
        }

        if ($removeImage || $imageBase64) {
            $this->images->deleteCurrent($customer);
            $customer->forceFill([
                'image_disk' => null,
                'image_path' => null,
                'image_original_name' => null,
                'image_mime_type' => null,
                'image_size' => null,
            ])->save();
        }

        if ($imageBase64) {
            $customer->fill($this->images->storeBase64(
                $customer,
                $imageBase64,
                $row['customer_image_original_name'] ?? null,
                $row['customer_image_mime_type'] ?? null,
            ))->save();
        }

        return $this->result($actor, $deviceId, $row['local_id'], $customer->refresh());
    }

    private function result(User $actor, ?string $deviceId, ?string $localId, ?Customer $customer): array
    {
        if ($customer && $deviceId !== null && $localId !== null) {
            CustomerSyncMapping::query()->updateOrCreate(
                [
                    'company_id' => $actor->company_id,
                    'user_id' => $actor->id,
                    'device_id' => $deviceId,
                    'local_id' => $localId,
                ],
                ['customer_uuid' => $customer->uuid],
            );
        }

        return [
            'mapping' => array_filter([
                'localId' => $localId,
                'serverId' => $customer?->uuid,
            ], fn (mixed $value): bool => $value !== null),
            'customer' => $customer && ! $customer->is_deleted && ! $customer->trashed()
                ? $this->serialize($customer)
                : $this->deletionAcknowledgement($localId, $customer),
        ];
    }

    private function deletionAcknowledgement(?string $localId, ?Customer $customer): array
    {
        return array_filter([
            'localId' => $localId,
            'serverId' => $customer?->uuid,
            'isSync' => true,
            'syncStatus' => 'synced',
            'isDeleted' => true,
        ], fn (mixed $value): bool => $value !== null);
    }

    private function accessibleQuery(User $actor): Builder
    {
        return Customer::query()
            ->when($actor->isSalesman(), function (Builder $query) use ($actor): void {
                $query->where(function (Builder $query) use ($actor): void {
                    $query
                        ->whereHas('users', function (Builder $query) use ($actor): void {
                            $query
                                ->where('users.uuid', $actor->uuid)
                                ->where('user_customer_access.is_deleted', false);
                        })
                        ->orWhereHas('plans.users', function (Builder $query) use ($actor): void {
                            $query
                                ->where('users.uuid', $actor->uuid)
                                ->where('user_plan_access.is_deleted', false);
                        });
                });
            });
    }

    private function normalize(array $row, ?string $operation): array
    {
        $normalized = [
            'local_id' => isset($row['localId']) || isset($row['local_id'])
                ? (string) ($row['localId'] ?? $row['local_id'])
                : null,
            'server_id' => $row['serverId'] ?? $row['server_id'] ?? $row['id'] ?? null,
            'sync_status' => $operation ?? $row['syncStatus'] ?? $row['sync_status'] ?? (
                isset($row['serverId']) || isset($row['server_id']) || isset($row['id'])
                    ? 'pending_update'
                    : 'pending_create'
            ),
            'updated_at' => $row['updatedAt'] ?? $row['updated_at'] ?? null,
        ];

        foreach ([
            'card_no' => ['cardNumber', 'card_no'],
            'name' => ['customerName', 'name'],
            'phone' => ['phoneNumber', 'phone'],
            'cnic' => ['cnic'],
            'address' => ['address'],
            'reference' => ['reference'],
            'customer_image_base64' => ['customerImageBase64', 'customer_image_base64'],
            'customer_image_original_name' => ['customerImageOriginalName', 'customer_image_original_name'],
            'customer_image_mime_type' => ['customerImageMimeType', 'customer_image_mime_type'],
            'remove_customer_image' => ['removeCustomerImage', 'remove_customer_image'],
        ] as $field => $aliases) {
            foreach ($aliases as $alias) {
                if (array_key_exists($alias, $row)) {
                    $normalized[$field] = $row[$alias];
                    break;
                }
            }
        }

        return $normalized;
    }

    public function serialize(Customer $customer): array
    {
        return [
            'serverId' => $customer->uuid,
            'cardNumber' => $customer->card_no,
            'customerName' => $customer->name,
            'phoneNumber' => $customer->phone,
            'cnic' => $customer->cnic,
            'address' => $customer->address,
            'reference' => $customer->reference,
            'customerImage' => $customer->image_disk && $customer->image_path
                ? url(\Illuminate\Support\Facades\Storage::disk($customer->image_disk)->url($customer->image_path))
                : null,
            'isSync' => true,
            'syncStatus' => 'synced',
            'isDeleted' => (bool) $customer->is_deleted,
            'deletedAt' => $customer->deleted_at?->toJSON(),
            'createdAt' => $customer->created_at?->toJSON(),
            'updatedAt' => $customer->updated_at?->toJSON(),
        ];
    }
}
