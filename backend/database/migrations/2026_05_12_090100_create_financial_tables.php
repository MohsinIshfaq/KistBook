<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('plans', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->uuid('customer_uuid');
            $table->uuid('product_uuid');
            $table->unsignedInteger('quantity')->default(1);
            $table->decimal('unit_price', 12, 2);
            $table->decimal('total_amount', 12, 2);
            $table->decimal('deposit_amount', 12, 2)->default(0);
            $table->decimal('installment_amount', 12, 2);
            $table->unsignedInteger('installment_count');
            $table->unsignedInteger('frequency_days')->default(30);
            $table->date('start_date');
            $table->text('notes')->nullable();
            $table->string('status')->default('active');
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();
            $table->softDeletes();

            $table->foreign('customer_uuid')->references('uuid')->on('customers');
            $table->foreign('product_uuid')->references('uuid')->on('products');
        });

        Schema::create('installments', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->uuid('plan_uuid');
            $table->unsignedInteger('sequence_number');
            $table->date('scheduled_due_date');
            $table->date('current_due_date');
            $table->decimal('amount', 12, 2);
            $table->decimal('paid_amount', 12, 2)->default(0);
            $table->string('status')->default('pending');
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['plan_uuid', 'sequence_number']);
            $table->foreign('plan_uuid')->references('uuid')->on('plans');
        });

        Schema::create('payments', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->uuid('operation_uuid')->unique();
            $table->uuid('customer_uuid');
            $table->uuid('plan_uuid');
            $table->uuid('installment_uuid');
            $table->decimal('amount', 12, 2);
            $table->date('paid_on');
            $table->text('note')->nullable();
            $table->string('source')->default('mobile');
            $table->uuid('created_by');
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();
            $table->softDeletes();

            $table->foreign('customer_uuid')->references('uuid')->on('customers');
            $table->foreign('plan_uuid')->references('uuid')->on('plans');
            $table->foreign('installment_uuid')->references('uuid')->on('installments');
            $table->foreign('created_by')->references('uuid')->on('users');
        });

        Schema::create('user_customer_access', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->uuid('user_uuid');
            $table->uuid('customer_uuid');
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['user_uuid', 'customer_uuid']);
            $table->foreign('user_uuid')->references('uuid')->on('users');
            $table->foreign('customer_uuid')->references('uuid')->on('customers');
        });

        Schema::create('user_plan_access', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->uuid('user_uuid');
            $table->uuid('plan_uuid');
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['user_uuid', 'plan_uuid']);
            $table->foreign('user_uuid')->references('uuid')->on('users');
            $table->foreign('plan_uuid')->references('uuid')->on('plans');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_plan_access');
        Schema::dropIfExists('user_customer_access');
        Schema::dropIfExists('payments');
        Schema::dropIfExists('installments');
        Schema::dropIfExists('plans');
    }
};
