<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customers', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->string('card_no')->unique();
            $table->string('name');
            $table->string('phone');
            $table->string('cnic')->unique();
            $table->text('address')->nullable();
            $table->string('reference')->nullable();
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('products', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->string('brand_name');
            $table->string('product_name');
            $table->string('code')->unique();
            $table->decimal('sales_price', 12, 2);
            $table->text('notes')->nullable();
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('product_categories', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->string('name')->unique();
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('product_category_map', function (Blueprint $table): void {
            $table->id();
            $table->uuid('product_uuid');
            $table->uuid('category_uuid');
            $table->timestamps();

            $table->unique(['product_uuid', 'category_uuid']);
            $table->foreign('product_uuid')->references('uuid')->on('products');
            $table->foreign('category_uuid')->references('uuid')->on('product_categories');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_category_map');
        Schema::dropIfExists('product_categories');
        Schema::dropIfExists('products');
        Schema::dropIfExists('customers');
    }
};
