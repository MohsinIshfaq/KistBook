<?php

namespace Tests\Feature\Api;

use App\Models\Customer;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BackendExpansionApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_camel_case_signup_and_profile_update_are_supported(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'firstName' => 'Ali',
            'lastName' => 'Raza',
            'email' => 'ali@example.com',
            'phoneNumber' => '03001112222',
            'password' => 'password',
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('user.firstName', 'Ali')
            ->assertJsonPath('user.lastName', 'Raza')
            ->assertJsonPath('user.phoneNumber', '03001112222')
            ->assertJsonMissingPath('user.first_name')
            ->assertJsonMissingPath('user.last_name')
            ->assertJsonMissingPath('user.phone')
            ->assertJsonMissingPath('user.company_id')
            ->assertJsonMissingPath('user.access_level')
            ->assertJsonMissingPath('user.is_active')
            ->assertJsonPath('company.name', 'Ali Raza Shop');

        $user = User::query()->where('email', 'ali@example.com')->firstOrFail();
        $this->assertTrue(Hash::check('password', $user->password));

        $this->withHeader('Authorization', 'Bearer '.$response->json('token'))
            ->patchJson('/api/auth/profile', [
                'firstName' => 'Ali Updated',
                'phoneNumber' => '03009998888',
            ])
            ->assertOk()
            ->assertJsonPath('data.firstName', 'Ali Updated')
            ->assertJsonPath('data.phoneNumber', '03009998888');
    }

    public function test_salesman_only_sees_assigned_customers_and_created_customer_is_auto_assigned(): void
    {
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);
        $hiddenCustomer = Customer::factory()->create(['company_id' => $owner->company_id]);
        $salesman = User::factory()->create(['company_id' => $owner->company_id]);

        Sanctum::actingAs($salesman);
        $this->getJson('/api/customers')->assertNotFound();
        $this->getJson('/api/customers/'.$hiddenCustomer->uuid)->assertNotFound();

        $create = $this->postJson('/api/customers/sync', [
            'deviceId' => 'salesman-phone',
            'customers' => [[
                'localId' => 'salesman-customer-1',
                'syncStatus' => 'pending_create',
                'cardNumber' => 'CARD-SALESMAN',
                'customerName' => 'Assigned Customer',
                'phoneNumber' => '03001230000',
                'cnic' => '42101-7654321-1',
                'address' => 'Lahore',
            ]],
        ]);

        $create
            ->assertOk()
            ->assertJsonPath('synced.0.customerName', 'Assigned Customer')
            ->assertJsonPath('synced.0.isSync', true);
        $serverId = $create->json('mappings.0.serverId');

        $this->getJson('/api/customers/'.$serverId)->assertOk();
        $this->getJson('/api/customers/sync')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.serverId', $serverId);
    }

    public function test_customer_image_is_stored_replaced_and_returned_through_sync(): void
    {
        Storage::fake('public');
        Sanctum::actingAs(User::factory()->owner()->create());

        $response = $this->postJson('/api/customers/sync', [
            'deviceId' => 'image-phone',
            'customers' => [[
                'localId' => 'image-customer-1',
                'syncStatus' => 'pending_create',
                'cardNumber' => 'CARD-IMAGE',
                'customerName' => 'Image Customer',
                'phoneNumber' => '03001234567',
                'cnic' => '42101-1111111-1',
                'customerImageBase64' => base64_encode('initial-image'),
                'customerImageOriginalName' => 'customer.jpg',
                'customerImageMimeType' => 'image/jpeg',
            ]],
        ]);

        $response->assertOk();
        $customer = Customer::query()->where('card_no', 'CARD-IMAGE')->firstOrFail();
        $originalImagePath = $customer->image_path;
        Storage::disk('public')->assertExists($customer->image_path);
        $this->assertNotNull($response->json('synced.0.customerImage'));

        $update = $this->putJson('/api/customers/sync', [
            'customers' => [[
                'serverId' => $customer->uuid,
                'cardNumber' => 'CARD-IMAGE-UPDATED',
                'customerName' => 'Updated Image Customer',
                'phoneNumber' => '03007654321',
                'cnic' => '42101-2222222-1',
                'address' => 'Karachi',
                'reference' => 'Updated reference',
                'customerImageBase64' => base64_encode('updated-image'),
                'customerImageOriginalName' => 'updated-customer.jpg',
                'customerImageMimeType' => 'image/jpeg',
            ]],
        ]);

        $update
            ->assertOk()
            ->assertJsonPath('synced.0.cardNumber', 'CARD-IMAGE-UPDATED')
            ->assertJsonPath('synced.0.customerName', 'Updated Image Customer')
            ->assertJsonPath('synced.0.phoneNumber', '03007654321')
            ->assertJsonPath('synced.0.cnic', '42101-2222222-1')
            ->assertJsonPath('synced.0.address', 'Karachi')
            ->assertJsonPath('synced.0.reference', 'Updated reference')
            ->assertJsonPath('synced.0.isSync', true);

        $customer->refresh();
        $this->assertNotSame($originalImagePath, $customer->image_path, 'Customer image path should change when a replacement image is uploaded.');
        Storage::disk('public')->assertMissing($originalImagePath);
        Storage::disk('public')->assertExists($customer->image_path);

        $replacementImagePath = $customer->image_path;
        $this->putJson('/api/customers/sync', [
            'customers' => [[
                'serverId' => $customer->uuid,
                'removeCustomerImage' => true,
            ]],
        ])
            ->assertOk()
            ->assertJsonPath('synced.0.customerImage', null);

        $customer->refresh();
        Storage::disk('public')->assertMissing($replacementImagePath);
        $this->assertNull($customer->image_path);
    }

    public function test_product_supports_generic_variants_and_authoritative_update(): void
    {
        Sanctum::actingAs(User::factory()->owner()->create());

        $create = $this->postJson('/api/products/sync', [
            'products' => [[
                'brandName' => 'Gree',
                'productName' => 'Inverter AC',
                'skuCode' => 'GREE-AC',
                'basePrice' => 185000,
                'variants' => [[
                    'skuCode' => 'GREE-AC-15T-PULAR',
                    'salePrice' => 190000,
                    'attributes' => [
                        ['name' => 'Capacity', 'value' => '1.5 Ton'],
                        ['name' => 'Series', 'value' => 'Pular'],
                    ],
                ]],
            ]],
        ]);

        $create
            ->assertOk()
            ->assertJsonPath('synced.0.basePrice', 185000)
            ->assertJsonPath('synced.0.variants.0.attributes.0.name', 'Capacity');

        $productUuid = $create->json('mappings.0.serverId');
        $variantUuid = $create->json('synced.0.variants.0.serverId');
        $this->putJson('/api/products/sync', [
            'products' => [[
                'serverId' => $productUuid,
                'variants' => [[
                    'serverId' => $variantUuid,
                    'skuCode' => 'GREE-AC-15T-PULAR',
                    'salePrice' => 192000,
                    'attributes' => [
                        ['name' => 'Inverter', 'value' => 'Yes'],
                    ],
                ]],
            ]],
        ])
            ->assertOk()
            ->assertJsonCount(1, 'synced.0.variants.0.attributes')
            ->assertJsonPath('synced.0.variants.0.attributes.0.name', 'Inverter');

        $this->getJson('/api/products/sync')
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }
}
