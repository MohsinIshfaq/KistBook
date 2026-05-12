<?php

namespace App\Contracts\Repositories;

use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Model;

interface UuidRepositoryInterface
{
    public function paginate(int $perPage = 15, array $with = []): LengthAwarePaginator;

    public function findByUuidOrFail(string $uuid, array $with = []): Model;

    public function create(array $data): Model;

    public function update(Model $model, array $data): Model;

    public function softDelete(Model $model): void;
}
