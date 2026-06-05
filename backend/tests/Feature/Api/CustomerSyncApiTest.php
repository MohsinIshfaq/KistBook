<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\CustomerSyncMapping;
use App\Models\Plan;
use App\Models\Product;
use App\Models\User;
use App\Models\UserPlanAccess;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CustomerSyncApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_create_upload_accepts_customer_fields_only_and_returns_index_mapping(): void
    {
        Storage::fake('public');
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);

        $response = $this->postJson('/api/customers/sync', [
            'customers' => [[
                'cardNumber' => 'SYNC-SIMPLE-1',
                'customerName' => 'Simple Sync Customer',
                'phoneNumber' => '03001110000',
                'cnic' => '42101-0000000-1',
                'address' => 'Lahore',
                'reference' => 'Mobile',
                'customerImageBase64' => base64_encode('simple-image'),
                'customerImageOriginalName' => 'customer.jpg',
                'customerImageMimeType' => 'image/jpeg',
            ]],
        ]);

        $response
            ->assertOk()
            ->assertJsonPath('mappings.0.index', 0)
            ->assertJsonMissingPath('mappings.0.localId')
            ->assertJsonPath('synced.0.customerName', 'Simple Sync Customer')
            ->assertJsonPath('synced.0.isSync', true)
            ->assertJsonPath('synced.0.syncStatus', 'synced');

        $customer = Customer::query()->where('card_no', 'SYNC-SIMPLE-1')->firstOrFail();
        $this->assertSame($customer->uuid, $response->json('mappings.0.serverId'));
        Storage::disk('public')->assertExists($customer->image_path);
        $this->assertSame(0, CustomerSyncMapping::query()->count());
    }

    public function test_http_methods_define_create_update_and_delete_operations(): void
    {
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);

        $create = $this->postJson('/api/customers/sync', [
            'customers' => [
                [
                    'cardNumber' => 'SYNC-METHOD-1',
                    'customerName' => 'Method Customer One',
                    'phoneNumber' => '03001110001',
                    'cnic' => '42101-0000000-2',
                ],
                [
                    'cardNumber' => 'SYNC-METHOD-2',
                    'customerName' => 'Method Customer Two',
                    'phoneNumber' => '03001110002',
                    'cnic' => '42101-0000000-3',
                ],
            ],
        ]);

        $create
            ->assertOk()
            ->assertJsonCount(2, 'synced')
            ->assertJsonPath('mappings.0.index', 0)
            ->assertJsonPath('mappings.1.index', 1);
        $firstServerId = $create->json('mappings.0.serverId');
        $secondServerId = $create->json('mappings.1.serverId');

        $this->putJson('/api/customers/sync', [
            'customers' => [[
                'serverId' => $firstServerId,
                'customerName' => 'Method Customer Updated',
                'address' => 'Karachi',
            ]],
        ])
            ->assertOk()
            ->assertJsonPath('synced.0.customerName', 'Method Customer Updated')
            ->assertJsonPath('synced.0.address', 'Karachi');

        $this->deleteJson('/api/customers/sync', [
            'customers' => [[
                'serverId' => $secondServerId,
            ]],
        ])
            ->assertOk()
            ->assertJsonPath('synced.0.serverId', $secondServerId)
            ->assertJsonPath('synced.0.isDeleted', true);

        $this->assertDatabaseHas('customers', [
            'uuid' => $firstServerId,
            'name' => 'Method Customer Updated',
        ]);
        $this->assertSoftDeleted('customers', ['uuid' => $secondServerId]);
    }

    public function test_upload_maps_local_ids_per_device_and_reports_partial_failures(): void
    {
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);

        $response = $this->postJson('/api/customers/sync', [
            'deviceId' => 'phone-a',
            'customers' => [
                [
                    'localId' => '1',
                    'syncStatus' => 'pending_create',
                    'cardNumber' => 'SYNC-1',
                    'customerName' => 'Sync Customer',
                    'phoneNumber' => '03001112223',
                    'cnic' => '42101-1234567-1',
                ],
                [
                    'localId' => '2',
                    'syncStatus' => 'pending_create',
                    'customerName' => 'Invalid Customer',
                ],
            ],
        ]);

        $response
            ->assertOk()
            ->assertJsonCount(1, 'mappings')
            ->assertJsonCount(1, 'failed')
            ->assertJsonPath('mappings.0.localId', '1')
            ->assertJsonPath('synced.0.isSync', true);
        $serverId = $response->json('mappings.0.serverId');
        $this->assertDatabaseHas('customer_sync_mappings', [
            'device_id' => 'phone-a',
            'local_id' => '1',
            'customer_uuid' => $serverId,
        ]);

        $this->postJson('/api/customers/sync', [
            'deviceId' => 'phone-b',
            'customers' => [[
                'localId' => '1',
                'syncStatus' => 'pending_create',
                'cardNumber' => 'SYNC-2',
                'customerName' => 'Other Device Customer',
                'phoneNumber' => '03001112224',
                'cnic' => '42101-1234567-2',
            ]],
        ])->assertOk();

        $this->assertSame(2, CustomerSyncMapping::query()->count());
    }

    public function test_download_honors_limit_order_and_excludes_deleted_customers(): void
    {
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);
        $first = Customer::factory()->create(['company_id' => $owner->company_id]);
        $second = Customer::factory()->create(['company_id' => $owner->company_id]);
        $first->forceFill(['updated_at' => now()->subSeconds(2)])->saveQuietly();
        $second->forceFill(['updated_at' => now()->subSecond()])->saveQuietly();

        $this->getJson('/api/customers/sync?lastUpdatedAt='.urlencode(now()->subMinute()->toJSON()).'&limit=1')
            ->assertOk()
            ->assertJsonPath('limit', 1)
            ->assertJsonPath('count', 1)
            ->assertJsonPath('hasMore', true)
            ->assertJsonPath('data.0.serverId', $first->uuid);

        $second->forceFill(['is_deleted' => true])->save();
        $second->delete();
        $this->getJson('/api/customers/sync?lastUpdatedAt='.urlencode(now()->subMinute()->toJSON()))
            ->assertOk()
            ->assertJsonPath('limit', 10)
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.serverId', $first->uuid)
            ->assertJsonPath('data.0.isDeleted', false)
            ->assertJsonMissingPath('data.0.id')
            ->assertJsonMissing(['serverId' => $second->uuid]);
    }

    public function test_delete_upload_returns_minimal_acknowledgement_and_is_not_downloaded(): void
    {
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);
        $customer = Customer::factory()->create(['company_id' => $owner->company_id]);

        $this->deleteJson('/api/customers/sync', [
            'customers' => [[
                'serverId' => $customer->uuid,
            ]],
        ])
            ->assertOk()
            ->assertJsonPath('synced.0.serverId', $customer->uuid)
            ->assertJsonPath('synced.0.isSync', true)
            ->assertJsonPath('synced.0.syncStatus', 'synced')
            ->assertJsonPath('synced.0.isDeleted', true)
            ->assertJsonMissingPath('synced.0.customerName');

        $this->assertSoftDeleted('customers', ['uuid' => $customer->uuid]);
        $this->getJson('/api/customers/sync')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_sync_upload_and_download_batches_are_capped_at_ten_customers(): void
    {
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);
        Customer::factory()->count(11)->create(['company_id' => $owner->company_id]);

        $this->getJson('/api/customers/sync')
            ->assertOk()
            ->assertJsonPath('limit', 10)
            ->assertJsonPath('count', 10)
            ->assertJsonPath('hasMore', true);

        $this->getJson('/api/customers/sync?limit=11')
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['limit']);

        $this->postJson('/api/customers/sync', [
            'deviceId' => 'phone-a',
            'customers' => array_fill(0, 11, []),
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['customers']);
    }

    public function test_download_cursor_does_not_skip_customers_with_the_same_timestamp(): void
    {
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);
        $timestamp = now()->subMinute()->startOfSecond();
        $customers = Customer::factory()->count(11)->create(['company_id' => $owner->company_id]);
        $customers->each(fn (Customer $customer) => $customer->forceFill(['updated_at' => $timestamp])->saveQuietly());

        $firstPage = $this->getJson('/api/customers/sync?'.http_build_query([
            'lastUpdatedAt' => $timestamp->copy()->subSecond()->toJSON(),
            'limit' => 10,
        ]));

        $firstPage
            ->assertOk()
            ->assertJsonPath('count', 10)
            ->assertJsonPath('hasMore', true);

        $secondPage = $this->getJson('/api/customers/sync?'.http_build_query([
            'lastUpdatedAt' => $firstPage->json('nextCursor.lastUpdatedAt'),
            'lastServerId' => $firstPage->json('nextCursor.lastServerId'),
            'limit' => 10,
        ]));

        $secondPage
            ->assertOk()
            ->assertJsonPath('count', 1)
            ->assertJsonPath('hasMore', false)
            ->assertJsonPath('nextCursor', null);

        $serverIds = collect($firstPage->json('data'))
            ->merge($secondPage->json('data'))
            ->pluck('serverId');
        $this->assertCount(11, $serverIds);
        $this->assertCount(11, $serverIds->unique());
    }

    public function test_salesman_downloads_customer_when_only_plan_is_assigned(): void
    {
        $owner = User::factory()->owner()->create();
        $salesman = User::factory()->create(['company_id' => $owner->company_id]);
        $customer = Customer::factory()->create(['company_id' => $owner->company_id]);
        $product = Product::factory()->create(['company_id' => $owner->company_id]);
        $plan = Plan::factory()->create([
            'company_id' => $owner->company_id,
            'customer_uuid' => $customer->uuid,
            'product_uuid' => $product->uuid,
        ]);
        UserPlanAccess::query()->create([
            'company_id' => $owner->company_id,
            'user_uuid' => $salesman->uuid,
            'plan_uuid' => $plan->uuid,
            'is_deleted' => false,
        ]);
        Sanctum::actingAs($salesman);

        $this->getJson('/api/customers/sync?lastUpdatedAt=2001-01-01T00:00:00.000Z')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.serverId', $customer->uuid);
    }

    public function test_newer_server_customer_is_returned_as_conflict(): void
    {
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);
        $customer = Customer::factory()->create(['company_id' => $owner->company_id]);

        $this->putJson('/api/customers/sync', [
            'customers' => [[
                'serverId' => $customer->uuid,
                'updatedAt' => now()->subDay()->toJSON(),
                'customerName' => 'Stale Name',
            ]],
        ])
            ->assertOk()
            ->assertJsonCount(1, 'conflicts')
            ->assertJsonPath('conflicts.0.serverId', $customer->uuid);
    }
}
