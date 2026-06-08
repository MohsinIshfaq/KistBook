<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('installments', function (Blueprint $table): void {
            if (! Schema::hasColumn('installments', 'previous_due_date')) {
                $table->date('previous_due_date')->nullable()->after('current_due_date');
            }

            if (! Schema::hasColumn('installments', 'reschedule_note')) {
                $table->text('reschedule_note')->nullable()->after('status');
            }

            if (! Schema::hasColumn('installments', 'rescheduled_at')) {
                $table->timestamp('rescheduled_at')->nullable()->after('reschedule_note');
            }
        });
    }

    public function down(): void
    {
        Schema::table('installments', function (Blueprint $table): void {
            foreach (['previous_due_date', 'reschedule_note', 'rescheduled_at'] as $column) {
                if (Schema::hasColumn('installments', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
