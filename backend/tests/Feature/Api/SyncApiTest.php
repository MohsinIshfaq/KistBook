<?php

namespace Tests\Feature\Api;

use App\Enums\AccessLevel;
use App\Models\Customer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SyncApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_upload_and_download_changed_records(): void
    {
        Sanctum::actingAs(User::factory()->create([
            'access_level' => AccessLevel::Owner,
            'role' => AccessLevel::Owner,
        ]));

        $uploadResponse = $this->postJson('/api/sync/upload', [
            'changes' => [
                'customers' => [
                    [
                        'local_id' => 101,
                        'card_no' => 'SYNC-1001',
                        'name' => 'Sync Customer',
                        'phone' => '03001112223',
                        'cnic' => '42101-1234567-1',
                        'address' => 'Lahore',
                        'reference' => 'Mobile app',
                        'is_deleted' => false,
                    ],
                ],
            ],
        ]);

        $uploadResponse
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.mappings.customers.0.local_id', 101);

        $serverId = $uploadResponse->json('data.mappings.customers.0.server_id');
        $this->assertNotEmpty($serverId);

        $this->assertDatabaseHas('customers', [
            'uuid' => $serverId,
            'cnic' => '42101-1234567-1',
            'is_deleted' => false,
        ]);

        $downloadResponse = $this->getJson('/api/sync/download?last_sync_date='.now()->subMinute()->toJSON());

        $downloadResponse
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.changes.customers.0.server_id', $serverId)
            ->assertJsonPath('data.changes.customers.0.name', 'Sync Customer');
    }

    public function test_owner_sync_download_only_contains_own_company_records(): void
    {
        $firstOwner = User::factory()->owner()->create();
        $secondOwner = User::factory()->owner()->create();
        $firstCustomer = Customer::factory()->create([
            'company_id' => $firstOwner->company_id,
        ]);
        Customer::factory()->create([
            'company_id' => $secondOwner->company_id,
        ]);
        Sanctum::actingAs($firstOwner);

        $response = $this->getJson('/api/sync/download');

        $response
            ->assertOk()
            ->assertJsonCount(1, 'data.changes.customers')
            ->assertJsonPath('data.changes.customers.0.server_id', $firstCustomer->uuid);
    }

    public function test_salesman_cannot_delete_user_through_sync(): void
    {
        $owner = User::factory()->owner()->create();
        $salesman = User::factory()->create([
            'company_id' => $owner->company_id,
        ]);
        Sanctum::actingAs($salesman);

        $response = $this->postJson('/api/sync/upload', [
            'changes' => [
                'users' => [
                    [
                        'server_id' => $salesman->uuid,
                        'is_deleted' => true,
                    ],
                ],
            ],
        ]);

        $response
            ->assertOk()
            ->assertJsonPath('data.errors.users.0.message', 'Only an owner can manage company users.');
        $this->assertDatabaseHas('users', [
            'uuid' => $salesman->uuid,
            'is_deleted' => false,
        ]);
    }
}
