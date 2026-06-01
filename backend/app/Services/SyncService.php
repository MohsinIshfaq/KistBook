<?php

namespace App\Services;

use App\Enums\AccessLevel;
use App\Models\Customer;
use App\Models\Installment;
use App\Models\Payment;
use App\Models\Plan;
use App\Models\Product;
use App\Models\ProductCategory;
use App\Models\ProductImage;
use App\Models\User;
use App\Models\UserCustomerAccess;
use App\Models\UserPlanAccess;
use BackedEnum;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Throwable;

class SyncService
{
    /** @var array<string, class-string<Model>> */
    private array $models = [
        'users' => User::class,
        'customers' => Customer::class,
        'products' => Product::class,
        'product_images' => ProductImage::class,
        'product_categories' => ProductCategory::class,
        'plans' => Plan::class,
        'installments' => Installment::class,
        'payments' => Payment::class,
        'user_customer_access' => UserCustomerAccess::class,
        'user_plan_access' => UserPlanAccess::class,
    ];

    /** @var array<int, string> */
    private array $downloadOrder = [
        'users',
        'customers',
        'products',
        'product_images',
        'plans',
        'installments',
        'payments',
        'user_customer_access',
        'user_plan_access',
    ];

    public function upload(array $changes, User $actor): array
    {
        $mappings = [];
        $errors = [];

        DB::transaction(function () use ($changes, $actor, &$mappings, &$errors): void {
            foreach ($this->downloadOrder as $tableName) {
                foreach (($changes[$tableName] ?? []) as $row) {
                    if (! is_array($row)) {
                        continue;
                    }

                    try {
                        $model = $this->upsertRow($tableName, $row, $actor);
                        $mappings[$tableName][] = [
                            'local_id' => $row['local_id'] ?? null,
                            'server_id' => $model?->uuid,
                            'date_updated' => $this->dateUpdated($model),
                            'is_deleted' => (bool) ($model?->is_deleted ?? false),
                        ];
                    } catch (Throwable $exception) {
                        $errors[$tableName][] = [
                            'local_id' => $row['local_id'] ?? null,
                            'message' => $exception->getMessage(),
                        ];
                    }
                }
            }
        });

        return [
            'server_time' => now()->toJSON(),
            'mappings' => $mappings,
            'errors' => $errors,
        ];
    }

    public function download(?string $lastSyncDate, User $actor): array
    {
        $since = $lastSyncDate ? Carbon::parse($lastSyncDate) : null;
        $changes = [];

        foreach ($this->downloadOrder as $tableName) {
            $modelClass = $this->models[$tableName];
            $query = $this->queryFor($modelClass);

            if ($since !== null) {
                $query->where(function (Builder $query) use ($since): void {
                    $query
                        ->where('date_updated', '>', $since)
                        ->orWhere(function (Builder $query) use ($since): void {
                            $query->whereNull('date_updated')->where('updated_at', '>', $since);
                        });
                });
            }

            $this->scopeForActor($query, $tableName, $actor);

            $changes[$tableName] = $query
                ->orderBy('date_updated')
                ->orderBy('id')
                ->get()
                ->map(fn (Model $model) => $this->serialize($tableName, $model))
                ->values()
                ->all();
        }

        return [
            'server_time' => now()->toJSON(),
            'changes' => $changes,
        ];
    }

    private function upsertRow(string $tableName, array $row, User $actor): ?Model
    {
        if (! isset($this->models[$tableName])) {
            throw new \InvalidArgumentException("Unsupported sync entity [$tableName].");
        }

        $model = $this->findExistingModel($tableName, $row);
        if ($tableName === 'users') {
            $this->authorizeUserSyncTarget($actor, $model);
        }
        if (($row['is_deleted'] ?? false) === true) {
            if ($model !== null) {
                $this->markDeleted($model);
            }

            return $model;
        }

        $data = $this->normalizeUploadData($tableName, $row, $actor, $model);
        if ($model === null) {
            $modelClass = $this->models[$tableName];
            $model = new $modelClass;
            $data['uuid'] = $data['uuid'] ?? $row['server_id'] ?? $row['uuid'] ?? (string) Str::uuid();
        }

        $model->fill($data);
        $model->save();

        if ($tableName === 'products') {
            $this->syncProductCategories($model, $row['categories'] ?? []);
        }

        return $model->refresh();
    }

    private function findExistingModel(string $tableName, array $row): ?Model
    {
        $modelClass = $this->models[$tableName];
        $query = $this->queryFor($modelClass);
        $uuid = $row['server_id'] ?? $row['uuid'] ?? null;

        if (is_string($uuid) && $uuid !== '') {
            $found = (clone $query)->where('uuid', $uuid)->first();
            if ($found !== null) {
                return $found;
            }
        }

        $unique = match ($tableName) {
            'users' => ['phone'],
            'customers' => ['cnic', 'card_no'],
            'products' => ['code'],
            'product_categories' => ['name'],
            'installments' => ['plan_uuid', 'sequence_number'],
            'payments' => ['operation_uuid'],
            'user_customer_access' => ['user_uuid', 'customer_uuid'],
            'user_plan_access' => ['user_uuid', 'plan_uuid'],
            default => [],
        };

        if ($unique === []) {
            return null;
        }

        foreach ($unique as $field) {
            if (! array_key_exists($field, $row) || $row[$field] === null || $row[$field] === '') {
                return null;
            }
        }

        return (clone $query)
            ->where(fn (Builder $query) => collect($unique)->each(
                fn (string $field) => $query->where($field, $row[$field])
            ))
            ->first();
    }

    private function normalizeUploadData(
        string $tableName,
        array $row,
        User $actor,
        ?Model $model,
    ): array {
        if ($tableName === 'users') {
            return $this->normalizeUserUploadData($row, $actor, $model);
        }

        $data = match ($tableName) {
            'customers' => $this->only($row, [
                'card_no',
                'name',
                'phone',
                'cnic',
                'address',
                'reference',
                'is_deleted',
            ]),
            'products' => $this->only($row, [
                'brand_name',
                'product_name',
                'code',
                'sales_price',
                'notes',
                'is_deleted',
            ]),
            'product_images' => $this->productImageData($row, $model),
            'plans' => $this->only($row, [
                'customer_uuid',
                'product_uuid',
                'quantity',
                'unit_price',
                'total_amount',
                'deposit_amount',
                'installment_amount',
                'installment_count',
                'frequency_days',
                'start_date',
                'notes',
                'status',
                'is_deleted',
            ]),
            'installments' => $this->only($row, [
                'plan_uuid',
                'sequence_number',
                'scheduled_due_date',
                'current_due_date',
                'amount',
                'paid_amount',
                'status',
                'is_deleted',
            ]),
            'payments' => $this->paymentData($row, $actor),
            'user_customer_access' => $this->only($row, [
                'uuid',
                'user_uuid',
                'customer_uuid',
                'is_deleted',
            ]),
            'user_plan_access' => $this->only($row, [
                'uuid',
                'user_uuid',
                'plan_uuid',
                'is_deleted',
            ]),
            default => [],
        };

        return $data;
    }

    private function normalizeUserUploadData(array $row, User $actor, ?Model $model): array
    {
        $model = $this->authorizeUserSyncTarget($actor, $model);
        $data = $this->only($row, [
            'phone',
            'email',
            'password',
            'first_name',
            'last_name',
            'is_active',
            'is_deleted',
        ]);
        $data['name'] = trim(implode(' ', array_filter([
            $data['first_name'] ?? $model->first_name,
            $data['last_name'] ?? $model->last_name,
        ])));
        $data['role'] = AccessLevel::Salesman;
        $data['access_level'] = AccessLevel::Salesman;
        $data['status'] = ($data['is_active'] ?? $model->is_active) ? 'active' : 'inactive';

        if (empty($data['password'])) {
            unset($data['password']);
        }

        return $data;
    }

    private function authorizeUserSyncTarget(User $actor, ?Model $model): User
    {
        if (! $actor->isOwner() || $actor->company_id === null) {
            throw new \RuntimeException('Only an owner can manage company users.');
        }

        if (! $model instanceof User) {
            throw new \RuntimeException('Create salesman users with the company users endpoint.');
        }

        if ($model->company_id !== $actor->company_id || $model->isOwner()) {
            throw new \RuntimeException('You can only manage salesmen in your own company.');
        }

        return $model;
    }

    private function productImageData(array $row, ?Model $model): array
    {
        $data = $this->only($row, [
            'product_uuid',
            'disk',
            'path',
            'original_name',
            'mime_type',
            'size',
            'sort_order',
            'is_deleted',
        ]);

        if (! empty($row['image_base64'])) {
            $stored = $this->storeProductImage($row);
            $data['disk'] = 'public';
            $data['path'] = $stored['path'];
            $data['original_name'] = $data['original_name'] ?? $stored['original_name'];
            $data['mime_type'] = $data['mime_type'] ?? $stored['mime_type'];
            $data['size'] = $data['size'] ?? $stored['size'];
        } elseif ($model !== null && empty($data['path'])) {
            unset($data['path']);
        }

        $data['disk'] = $data['disk'] ?? 'public';

        return $data;
    }

    private function paymentData(array $row, User $actor): array
    {
        $data = $this->only($row, [
            'uuid',
            'operation_uuid',
            'customer_uuid',
            'plan_uuid',
            'installment_uuid',
            'amount',
            'paid_on',
            'note',
            'source',
            'created_by',
            'is_deleted',
        ]);
        $data['operation_uuid'] = $data['operation_uuid'] ?? (string) Str::uuid();
        $data['created_by'] = $actor->uuid;
        $data['source'] = $data['source'] ?? 'mobile';

        return $data;
    }

    private function storeProductImage(array $row): array
    {
        $bytes = base64_decode((string) $row['image_base64'], true);
        if ($bytes === false) {
            throw new \InvalidArgumentException('Invalid product image payload.');
        }

        $originalName = $row['original_name'] ?? 'product-image.jpg';
        $extension = strtolower(pathinfo((string) $originalName, PATHINFO_EXTENSION)) ?: 'jpg';
        $extension = in_array($extension, ['jpg', 'jpeg', 'png', 'webp', 'heic'], true) ? $extension : 'jpg';
        $path = 'product-images/'.Str::uuid().'.'.$extension;

        Storage::disk('public')->put($path, $bytes);

        return [
            'path' => $path,
            'original_name' => $originalName,
            'mime_type' => $row['mime_type'] ?? match ($extension) {
                'png' => 'image/png',
                'webp' => 'image/webp',
                'heic' => 'image/heic',
                default => 'image/jpeg',
            },
            'size' => strlen($bytes),
        ];
    }

    private function syncProductCategories(Product $product, mixed $categories): void
    {
        if (! is_array($categories)) {
            return;
        }

        $categoryUuids = collect($categories)
            ->map(fn (mixed $category) => trim((string) $category))
            ->filter()
            ->unique()
            ->map(function (string $name): string {
                $category = ProductCategory::query()->firstOrCreate(
                    ['name' => $name],
                    ['uuid' => (string) Str::uuid(), 'is_deleted' => false],
                );

                return $category->uuid;
            })
            ->values()
            ->all();

        $product->categories()->sync($categoryUuids);
    }

    private function serialize(string $tableName, Model $model): array
    {
        $base = [
            'server_id' => $model->uuid,
            'uuid' => $model->uuid,
            'is_deleted' => (bool) ($model->is_deleted ?? false),
            'date_updated' => $this->dateUpdated($model),
            'created_at' => $model->created_at?->toJSON(),
            'updated_at' => $model->updated_at?->toJSON(),
        ];

        return $base + match ($tableName) {
            'users' => [
                'company_id' => $model->company_id,
                'name' => $model->name,
                'phone' => $model->phone,
                'email' => $model->email,
                'first_name' => $model->first_name,
                'last_name' => $model->last_name,
                'access_level' => $model->access_level instanceof AccessLevel
                    ? $model->access_level->value
                    : $model->access_level,
                'role' => $model->role instanceof AccessLevel
                    ? $model->role->value
                    : $model->role,
                'status' => $model->status,
                'is_active' => (bool) $model->is_active,
            ],
            'customers' => $this->modelOnly($model, ['card_no', 'name', 'phone', 'cnic', 'address', 'reference']),
            'products' => $this->serializeProduct($model),
            'product_images' => $this->serializeProductImage($model),
            'plans' => $this->serializePlan($model),
            'installments' => $this->modelOnly($model, [
                'plan_uuid',
                'sequence_number',
                'scheduled_due_date',
                'current_due_date',
                'amount',
                'paid_amount',
                'status',
            ]),
            'payments' => $this->modelOnly($model, [
                'operation_uuid',
                'customer_uuid',
                'plan_uuid',
                'installment_uuid',
                'amount',
                'paid_on',
                'note',
                'source',
                'created_by',
            ]),
            'user_customer_access' => $this->modelOnly($model, ['user_uuid', 'customer_uuid']),
            'user_plan_access' => $this->modelOnly($model, ['user_uuid', 'plan_uuid']),
            default => [],
        };
    }

    private function serializeProduct(Model $model): array
    {
        /** @var Product $model */
        return $this->modelOnly($model, ['brand_name', 'product_name', 'code', 'sales_price', 'notes']) + [
            'categories' => $model->categories()->pluck('name')->values()->all(),
        ];
    }

    private function serializeProductImage(Model $model): array
    {
        /** @var ProductImage $model */
        return $this->modelOnly($model, [
            'product_uuid',
            'disk',
            'path',
            'original_name',
            'mime_type',
            'size',
            'sort_order',
        ]) + [
            'image_url' => $model->path ? url(Storage::disk($model->disk)->url($model->path)) : null,
        ];
    }

    private function serializePlan(Model $model): array
    {
        /** @var Plan $model */
        return $this->modelOnly($model, [
            'customer_uuid',
            'product_uuid',
            'quantity',
            'unit_price',
            'total_amount',
            'deposit_amount',
            'installment_amount',
            'installment_count',
            'frequency_days',
            'start_date',
            'notes',
            'status',
        ]) + [
            'product_name' => $model->product?->product_name,
        ];
    }

    private function markDeleted(Model $model): void
    {
        $model->forceFill([
            'is_deleted' => true,
            'date_updated' => now(),
        ])->save();

        if ($this->usesSoftDeletes($model::class) && method_exists($model, 'trashed') && ! $model->trashed()) {
            $model->delete();
        }
    }

    /**
     * @param  class-string<Model>  $modelClass
     */
    private function queryFor(string $modelClass): Builder
    {
        $query = $modelClass::query();

        if ($this->usesSoftDeletes($modelClass)) {
            $query->withTrashed();
        }

        return $query;
    }

    private function scopeForActor(Builder $query, string $tableName, User $actor): void
    {
        if ($tableName === 'users') {
            if ($actor->isSalesman() || $actor->company_id === null) {
                $query->where('uuid', $actor->uuid);

                return;
            }

            $query->where('company_id', $actor->company_id);

            return;
        }

        if (! $actor->isSalesman()) {
            return;
        }

        match ($tableName) {
            'customers' => $query->whereIn('uuid', $this->assignedCustomerUuids($actor)),
            'plans' => $query->whereIn('uuid', $this->assignedPlanUuids($actor)),
            'installments' => $query->whereIn('plan_uuid', $this->assignedPlanUuids($actor)),
            'payments' => $query->whereIn('plan_uuid', $this->assignedPlanUuids($actor)),
            'user_customer_access', 'user_plan_access' => $query->where('user_uuid', $actor->uuid),
            default => null,
        };
    }

    /**
     * @return array<int, string>
     */
    private function assignedCustomerUuids(User $actor): array
    {
        return UserCustomerAccess::query()
            ->where('user_uuid', $actor->uuid)
            ->where('is_deleted', false)
            ->pluck('customer_uuid')
            ->all();
    }

    /**
     * @return array<int, string>
     */
    private function assignedPlanUuids(User $actor): array
    {
        return UserPlanAccess::query()
            ->where('user_uuid', $actor->uuid)
            ->where('is_deleted', false)
            ->pluck('plan_uuid')
            ->all();
    }

    private function dateUpdated(?Model $model): ?string
    {
        if ($model === null) {
            return null;
        }

        $value = $model->date_updated ?? $model->updated_at ?? now();

        return $value instanceof Carbon
            ? $value->toJSON()
            : Carbon::parse($value)->toJSON();
    }

    /**
     * @return array<string, mixed>
     */
    private function only(array $row, array $keys): array
    {
        $values = [];
        foreach ($keys as $key) {
            if (array_key_exists($key, $row)) {
                $values[$key] = $row[$key];
            }
        }

        return $values;
    }

    /**
     * @return array<string, mixed>
     */
    private function modelOnly(Model $model, array $keys): array
    {
        $values = [];
        foreach ($keys as $key) {
            $values[$key] = $this->serializeValue($model->{$key});
        }

        return $values;
    }

    private function serializeValue(mixed $value): mixed
    {
        if ($value instanceof BackedEnum) {
            return $value->value;
        }

        if ($value instanceof Carbon) {
            return $value->toJSON();
        }

        return $value;
    }

    /**
     * @param  class-string<Model>  $modelClass
     */
    private function usesSoftDeletes(string $modelClass): bool
    {
        return in_array(SoftDeletes::class, class_uses_recursive($modelClass), true);
    }
}
