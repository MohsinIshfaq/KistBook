<?php

namespace Tests\Feature\Api;

use App\Models\Product;
use App\Models\ProductCategory;
use App\Models\ProductImage;
use App\Models\ProductVariant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProductSyncApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_http_methods_sync_products_with_images_categories_and_generic_variants(): void
    {
        Storage::fake('public');
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);
        $category = ProductCategory::factory()->create(['company_id' => $owner->company_id]);

        $create = $this->postJson('/api/products/sync', [
            'products' => [
                [
                    'categoryId' => $category->uuid,
                    'brandName' => 'Gree',
                    'productName' => 'Inverter AC',
                    'skuCode' => 'SYNC-GREE-AC',
                    'salesPrice' => 185000,
                    'notes' => 'Offline product',
                    'productImages' => [[
                        'imageBase64' => base64_encode('ac-image'),
                        'originalName' => 'ac.jpg',
                        'mimeType' => 'image/jpeg',
                    ]],
                    'variants' => [[
                        'skuCode' => 'SYNC-GREE-AC-15T',
                        'salePrice' => 190000,
                        'attributes' => [
                            ['name' => 'Capacity', 'value' => '1.5 Ton'],
                            ['name' => 'Inverter', 'value' => 'Yes'],
                        ],
                    ]],
                ],
                [
                    'productName' => 'Smart LED',
                    'salesPrice' => 125000,
                ],
            ],
        ]);

        $create
            ->assertOk()
            ->assertJsonCount(2, 'mappings')
            ->assertJsonCount(2, 'synced')
            ->assertJsonPath('mappings.0.index', 0)
            ->assertJsonPath('mappings.1.index', 1)
            ->assertJsonPath('synced.0.categoryId', $category->uuid)
            ->assertJsonPath('synced.0.salesPrice', 185000)
            ->assertJsonPath('synced.1.productName', 'Smart LED')
            ->assertJsonPath('synced.1.salesPrice', 125000)
            ->assertJsonPath('synced.0.variants.0.attributes.0.name', 'Capacity')
            ->assertJsonPath('synced.0.isSync', true);
        $this->assertArrayNotHasKey('basePrice', $create->json('synced.0'));

        $firstServerId = $create->json('mappings.0.serverId');
        $secondServerId = $create->json('mappings.1.serverId');
        $variantServerId = $create->json('synced.0.variants.0.serverId');
        $originalImage = ProductImage::query()->where('product_uuid', $firstServerId)->firstOrFail();
        Storage::disk('public')->assertExists($originalImage->path);

        $update = $this->putJson('/api/products/sync', [
            'products' => [[
                'serverId' => $firstServerId,
                'productName' => 'Inverter AC Updated',
                'salesPrice' => 192000,
                'productImages' => [[
                    'imageBase64' => base64_encode('updated-ac-image'),
                    'originalName' => 'updated-ac.jpg',
                    'mimeType' => 'image/jpeg',
                ]],
                'variants' => [[
                    'serverId' => $variantServerId,
                    'skuCode' => 'SYNC-GREE-AC-15T',
                    'salePrice' => 195000,
                    'attributes' => [
                        ['name' => 'Series', 'value' => 'Pular'],
                    ],
                ]],
            ]],
        ]);

        $update
            ->assertOk()
            ->assertJsonPath('synced.0.productName', 'Inverter AC Updated')
            ->assertJsonPath('synced.0.salesPrice', 192000)
            ->assertJsonCount(1, 'synced.0.productImages')
            ->assertJsonCount(1, 'synced.0.variants.0.attributes')
            ->assertJsonPath('synced.0.variants.0.attributes.0.name', 'Series');

        Storage::disk('public')->assertMissing($originalImage->path);
        $replacementImage = ProductImage::query()->where('product_uuid', $firstServerId)->firstOrFail();
        Storage::disk('public')->assertExists($replacementImage->path);

        $this->putJson('/api/products/sync', [
            'products' => [[
                'serverId' => $firstServerId,
                'productImages' => [[
                    'imageBase64' => 'invalid-base64***',
                    'originalName' => 'broken.jpg',
                    'mimeType' => 'image/jpeg',
                ]],
            ]],
        ])
            ->assertOk()
            ->assertJsonCount(1, 'failed');

        Storage::disk('public')->assertExists($replacementImage->path);
        $this->assertDatabaseHas('product_images', [
            'uuid' => $replacementImage->uuid,
            'deleted_at' => null,
        ]);

        $this->deleteJson('/api/products/sync', [
            'products' => [
                ['serverId' => $firstServerId],
                ['serverId' => $secondServerId],
            ],
        ])
            ->assertOk()
            ->assertJsonCount(2, 'synced')
            ->assertJsonPath('synced.0.isDeleted', true)
            ->assertJsonPath('synced.1.isDeleted', true);

        $this->assertSoftDeleted('products', ['uuid' => $firstServerId]);
        $this->assertSoftDeleted('products', ['uuid' => $secondServerId]);
        $this->getJson('/api/products/sync')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_product_sync_download_is_cursor_safe_and_batches_are_capped_at_ten(): void
    {
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);
        $timestamp = now()->subMinute()->startOfSecond();
        $products = Product::factory()->count(11)->create(['company_id' => $owner->company_id]);
        $products->each(fn (Product $product) => $product->forceFill(['updated_at' => $timestamp])->saveQuietly());

        $firstPage = $this->getJson('/api/products/sync?'.http_build_query([
            'lastUpdatedAt' => $timestamp->copy()->subSecond()->toJSON(),
            'limit' => 10,
        ]));
        $firstPage
            ->assertOk()
            ->assertJsonPath('count', 10)
            ->assertJsonPath('hasMore', true);

        $secondPage = $this->getJson('/api/products/sync?'.http_build_query([
            'lastUpdatedAt' => $firstPage->json('nextCursor.lastUpdatedAt'),
            'lastServerId' => $firstPage->json('nextCursor.lastServerId'),
            'limit' => 10,
        ]));
        $secondPage
            ->assertOk()
            ->assertJsonPath('count', 1)
            ->assertJsonPath('hasMore', false);

        $this->getJson('/api/products/sync?limit=11')
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['limit']);
        $this->postJson('/api/products/sync', [
            'products' => array_fill(0, 11, []),
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['products']);
    }

    public function test_product_sync_reports_partial_validation_failures(): void
    {
        $owner = User::factory()->owner()->create();
        Sanctum::actingAs($owner);

        $this->postJson('/api/products/sync', [
            'products' => [
                [
                    'productName' => 'Reno 13',
                    'salesPrice' => 145000,
                ],
                [
                    'productName' => 'Incomplete',
                ],
            ],
        ])
            ->assertOk()
            ->assertJsonCount(1, 'synced')
            ->assertJsonCount(1, 'failed')
            ->assertJsonPath('failed.0.index', 1);
    }
}
