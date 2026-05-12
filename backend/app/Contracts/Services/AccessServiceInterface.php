<?php

namespace App\Contracts\Services;

interface AccessServiceInterface
{
    public function assignCustomer(string $userUuid, string $customerUuid): array;

    public function assignPlan(string $userUuid, string $planUuid): array;
}
