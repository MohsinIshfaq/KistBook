<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_price_histories', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->foreignId('company_id')->constrained('companies')->cascadeOnDelete();
            $table->uuid('product_uuid');
            $table->decimal('previous_price', 12, 2)->nullable();
            $table->decimal('new_price', 12, 2);
            $table->timestamp('changed_at')->index();
            $table->string('source', 50)->default('product');
            $table->uuid('created_by')->nullable();
            $table->timestamps();

            $table->index(['company_id', 'product_uuid', 'changed_at'], 'product_price_histories_company_product_changed_idx');
            $table->foreign('product_uuid')->references('uuid')->on('products')->cascadeOnDelete();
            $table->foreign('created_by')->references('uuid')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_price_histories');
    }
};
