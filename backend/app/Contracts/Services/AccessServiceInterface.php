<?php

namespace App\Contracts\Services;

interface AccessServiceInterface
{
    public function assignCustomer(string $userUuid, string $customerUuid): array;

    public function assignPlan(string $userUuid, string $planUuid): array;

    /**
     * @param  array<int, string>  $customerUuids
     * @param  array<int, string>  $planUuids
     */
    public function replaceAssignments(string $userUuid, array $customerUuids, array $planUuids): array;
}
