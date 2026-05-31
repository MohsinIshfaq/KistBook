<?php

namespace App\Traits;

use App\Enums\SyncOperation;
use App\Models\SyncChangeLog;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Schema;

trait LogsSyncChanges
{
    /** @var array<string, bool> */
    private static array $dateUpdatedColumns = [];

    protected static function bootLogsSyncChanges(): void
    {
        static::saving(function ($model): void {
            if ($model->hasDateUpdatedColumn()) {
                $model->forceFill(['date_updated' => now()]);
            }
        });

        static::created(fn ($model) => $model->writeSyncChange(SyncOperation::Created));
        static::updated(fn ($model) => $model->writeSyncChange(SyncOperation::Updated));
        static::deleted(fn ($model) => $model->writeSyncChange(SyncOperation::Deleted));
    }

    public function writeSyncChange(SyncOperation $operation): void
    {
        if (! isset($this->uuid)) {
            return;
        }

        $latestVersion = SyncChangeLog::query()
            ->where('entity_type', $this->getTable())
            ->where('entity_uuid', $this->uuid)
            ->max('version_no') ?? 0;

        SyncChangeLog::query()->create([
            'entity_type' => $this->getTable(),
            'entity_uuid' => $this->uuid,
            'operation' => $operation->value,
            'changed_at' => now(),
            'changed_by' => Auth::user()?->uuid,
            'version_no' => $latestVersion + 1,
        ]);
    }

    private function hasDateUpdatedColumn(): bool
    {
        $table = $this->getTable();

        return self::$dateUpdatedColumns[$table] ??= Schema::hasColumn($table, 'date_updated');
    }
}
