<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /** @var array<int, string> */
    private array $tables = [
        'users',
        'customers',
        'products',
        'product_images',
        'product_categories',
        'plans',
        'installments',
        'payments',
        'user_customer_access',
        'user_plan_access',
    ];

    public function up(): void
    {
        foreach ($this->tables as $tableName) {
            if (! Schema::hasTable($tableName)) {
                continue;
            }

            Schema::table($tableName, function (Blueprint $table) use ($tableName): void {
                if (! Schema::hasColumn($tableName, 'date_updated')) {
                    $table->timestamp('date_updated')->nullable()->index()->after('updated_at');
                }

                if ($tableName === 'product_images' && ! Schema::hasColumn($tableName, 'is_deleted')) {
                    $table->boolean('is_deleted')->default(false)->after('sort_order');
                    $table->softDeletes();
                }
            });

            DB::table($tableName)
                ->whereNull('date_updated')
                ->update(['date_updated' => DB::raw('COALESCE(updated_at, created_at, CURRENT_TIMESTAMP)')]);
        }
    }

    public function down(): void
    {
        foreach (array_reverse($this->tables) as $tableName) {
            if (! Schema::hasTable($tableName)) {
                continue;
            }

            Schema::table($tableName, function (Blueprint $table) use ($tableName): void {
                if (Schema::hasColumn($tableName, 'date_updated')) {
                    $table->dropColumn('date_updated');
                }

                if ($tableName === 'product_images') {
                    if (Schema::hasColumn($tableName, 'deleted_at')) {
                        $table->dropSoftDeletes();
                    }
                    if (Schema::hasColumn($tableName, 'is_deleted')) {
                        $table->dropColumn('is_deleted');
                    }
                }
            });
        }
    }
};
