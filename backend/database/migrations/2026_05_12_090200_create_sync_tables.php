<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sync_change_log', function (Blueprint $table): void {
            $table->id();
            $table->string('entity_type');
            $table->uuid('entity_uuid');
            $table->string('operation');
            $table->timestamp('changed_at');
            $table->uuid('changed_by')->nullable();
            $table->unsignedBigInteger('version_no')->default(1);
            $table->timestamps();

            $table->index(['entity_type', 'entity_uuid']);
            $table->foreign('changed_by')->references('uuid')->on('users');
        });

        Schema::create('device_sync_state', function (Blueprint $table): void {
            $table->id();
            $table->uuid('user_uuid');
            $table->string('device_id');
            $table->timestamp('last_pulled_at')->nullable();
            $table->timestamp('last_push_ack_at')->nullable();
            $table->string('last_cursor')->nullable();
            $table->timestamps();

            $table->unique(['user_uuid', 'device_id']);
            $table->foreign('user_uuid')->references('uuid')->on('users');
        });

        Schema::create('sync_conflicts', function (Blueprint $table): void {
            $table->id();
            $table->string('device_id');
            $table->string('entity_type');
            $table->uuid('entity_uuid');
            $table->unsignedBigInteger('local_version');
            $table->unsignedBigInteger('server_version');
            $table->text('reason');
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sync_conflicts');
        Schema::dropIfExists('device_sync_state');
        Schema::dropIfExists('sync_change_log');
    }
};
