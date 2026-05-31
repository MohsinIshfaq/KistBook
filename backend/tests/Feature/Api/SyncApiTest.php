<?php

namespace Tests\Feature\Api;

use App\Enums\AccessLevel;
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
}
