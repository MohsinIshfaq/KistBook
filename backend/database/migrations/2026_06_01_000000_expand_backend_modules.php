<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            $table->string('image_disk')->nullable()->after('reference');
            $table->string('image_path')->nullable()->after('image_disk');
            $table->string('image_original_name')->nullable()->after('image_path');
            $table->string('image_mime_type', 100)->nullable()->after('image_original_name');
            $table->unsignedBigInteger('image_size')->nullable()->after('image_mime_type');
            $table->index(['company_id', 'updated_at']);
        });

        Schema::table('customers', function (Blueprint $table): void {
            $table->dropUnique('customers_card_no_unique');
            $table->dropUnique('customers_cnic_unique');
            $table->unique(['company_id', 'card_no']);
            $table->unique(['company_id', 'cnic']);
        });

        Schema::create('customer_sync_mappings', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('company_id')->constrained('companies')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('device_id', 191);
            $table->string('local_id', 191);
            $table->uuid('customer_uuid');
            $table->timestamps();

            $table->unique(['company_id', 'user_id', 'device_id', 'local_id'], 'customer_sync_mappings_device_local_unique');
            $table->index(['company_id', 'customer_uuid']);
            $table->foreign('customer_uuid')->references('uuid')->on('customers')->cascadeOnDelete();
        });

        Schema::table('product_categories', function (Blueprint $table): void {
            $table->dropUnique('product_categories_name_unique');
            $table->unique(['company_id', 'name']);
        });

        Schema::table('products', function (Blueprint $table): void {
            $table->decimal('base_price', 12, 2)->nullable()->after('sales_price');
            $table->uuid('primary_category_uuid')->nullable()->after('base_price');
            $table->dropUnique('products_code_unique');
            $table->unique(['company_id', 'code']);
            $table->index(['company_id', 'updated_at']);
            $table->foreign('primary_category_uuid')->references('uuid')->on('product_categories')->nullOnDelete();
        });

        DB::table('products')->whereNull('base_price')->update([
            'base_price' => DB::raw('sales_price'),
        ]);

        Schema::create('product_variants', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->foreignId('company_id')->nullable()->constrained('companies')->nullOnDelete();
            $table->uuid('product_uuid');
            $table->string('sku_code', 100);
            $table->decimal('sale_price', 12, 2);
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();
            $table->timestamp('date_updated')->nullable()->index();
            $table->softDeletes();

            $table->unique(['company_id', 'sku_code']);
            $table->index(['product_uuid', 'updated_at']);
            $table->foreign('product_uuid')->references('uuid')->on('products')->cascadeOnDelete();
        });

        Schema::create('product_variant_attributes', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->foreignId('company_id')->nullable()->constrained('companies')->nullOnDelete();
            $table->uuid('variant_uuid');
            $table->string('name', 100);
            $table->string('value', 255);
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();
            $table->timestamp('date_updated')->nullable()->index();
            $table->softDeletes();

            $table->index(['variant_uuid', 'name']);
            $table->foreign('variant_uuid')->references('uuid')->on('product_variants')->cascadeOnDelete();
        });

        Schema::table('plans', function (Blueprint $table): void {
            $table->string('mode', 20)->default('legacy')->after('product_uuid');
            $table->decimal('remaining_amount', 12, 2)->default(0)->after('deposit_amount');
            $table->index(['company_id', 'updated_at']);
        });

        Schema::create('installment_plan_items', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->foreignId('company_id')->nullable()->constrained('companies')->nullOnDelete();
            $table->uuid('plan_uuid');
            $table->uuid('product_uuid');
            $table->uuid('variant_uuid')->nullable();
            $table->unsignedInteger('quantity')->default(1);
            $table->decimal('unit_price_snapshot', 12, 2);
            $table->decimal('total_amount', 12, 2);
            $table->decimal('deposit_amount', 12, 2)->default(0);
            $table->decimal('installment_amount', 12, 2);
            $table->unsignedInteger('frequency_days');
            $table->date('first_due_date');
            $table->string('item_name')->nullable();
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();
            $table->timestamp('date_updated')->nullable()->index();
            $table->softDeletes();

            $table->index(['plan_uuid', 'product_uuid']);
            $table->foreign('plan_uuid')->references('uuid')->on('plans')->cascadeOnDelete();
            $table->foreign('product_uuid')->references('uuid')->on('products');
            $table->foreign('variant_uuid')->references('uuid')->on('product_variants')->nullOnDelete();
        });

        Schema::table('installments', function (Blueprint $table): void {
            $table->uuid('plan_item_uuid')->nullable()->after('plan_uuid');
            $table->string('schedule_group', 20)->default('legacy')->after('plan_item_uuid');
            $table->unsignedInteger('item_sequence_number')->nullable()->after('sequence_number');
            $table->index(['plan_uuid', 'plan_item_uuid']);
            $table->foreign('plan_item_uuid')->references('uuid')->on('installment_plan_items')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('installments', function (Blueprint $table): void {
            $table->dropForeign(['plan_item_uuid']);
            $table->dropIndex(['plan_uuid', 'plan_item_uuid']);
            $table->dropColumn(['plan_item_uuid', 'schedule_group', 'item_sequence_number']);
        });

        Schema::dropIfExists('installment_plan_items');

        Schema::table('plans', function (Blueprint $table): void {
            $table->dropIndex(['company_id', 'updated_at']);
            $table->dropColumn(['mode', 'remaining_amount']);
        });

        Schema::dropIfExists('product_variant_attributes');
        Schema::dropIfExists('product_variants');

        Schema::table('products', function (Blueprint $table): void {
            $table->dropForeign(['primary_category_uuid']);
            $table->dropIndex(['company_id', 'updated_at']);
            $table->dropUnique(['company_id', 'code']);
            $table->unique('code');
            $table->dropColumn(['base_price', 'primary_category_uuid']);
        });

        Schema::table('product_categories', function (Blueprint $table): void {
            $table->dropUnique(['company_id', 'name']);
            $table->unique('name');
        });

        Schema::dropIfExists('customer_sync_mappings');

        Schema::table('customers', function (Blueprint $table): void {
            $table->dropIndex(['company_id', 'updated_at']);
            $table->dropUnique(['company_id', 'card_no']);
            $table->dropUnique(['company_id', 'cnic']);
            $table->unique('card_no');
            $table->unique('cnic');
            $table->dropColumn([
                'image_disk',
                'image_path',
                'image_original_name',
                'image_mime_type',
                'image_size',
            ]);
        });
    }
};
