<?php

namespace App\Repositories;

use App\Contracts\Repositories\UuidRepositoryInterface;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

abstract class BaseRepository implements UuidRepositoryInterface
{
    public function __construct(protected Model $model)
    {
    }

    public function paginate(int $perPage = 15, array $with = []): LengthAwarePaginator
    {
        return $this->model->newQuery()->with($with)->latest()->paginate($perPage);
    }

    public function findByUuidOrFail(string $uuid, array $with = []): Model
    {
        return $this->model->newQuery()->with($with)->where('uuid', $uuid)->firstOrFail();
    }

    public function create(array $data): Model
    {
        if (! array_key_exists('uuid', $data) && $this->model->getConnection()->getSchemaBuilder()->hasColumn($this->model->getTable(), 'uuid')) {
            $data['uuid'] = (string) Str::uuid();
        }

        return $this->model->newQuery()->create($data);
    }

    public function update(Model $model, array $data): Model
    {
        $model->fill($data);
        $model->save();

        return $model->refresh();
    }

    public function softDelete(Model $model): void
    {
        $model->forceFill(['is_deleted' => true])->save();
        $model->delete();
    }
}
