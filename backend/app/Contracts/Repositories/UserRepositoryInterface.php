<?php

namespace App\Contracts\Repositories;

use App\Models\User;

interface UserRepositoryInterface
{
    public function create(array $data): User;

    public function findByPhone(string $phone): ?User;

    public function findByLogin(string $login): ?User;

    public function findByUuidOrFail(string $uuid): User;
}
