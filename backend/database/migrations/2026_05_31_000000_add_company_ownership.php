<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /** @var array<int, string> */
    private array $companyOwnedTables = [
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
        Schema::create('companies', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->string('name');
            $table->string('phone', 30)->nullable();
            $table->string('email')->nullable();
            $table->text('address')->nullable();
            $table->foreignId('owner_id')->nullable()->unique()->constrained('users')->nullOnDelete();
            $table->string('status')->default('active');
            $table->timestamps();
        });

        Schema::table('users', function (Blueprint $table): void {
            $table->foreignId('company_id')->nullable()->after('uuid')->constrained('companies')->nullOnDelete();
            $table->string('name')->nullable()->after('company_id');
            $table->string('role')->default('salesman')->after('last_name');
            $table->string('status')->default('active')->after('role');
        });

        DB::table('users')->orderBy('id')->each(function (object $user): void {
            $name = trim(implode(' ', array_filter([
                $user->first_name ?? null,
                $user->last_name ?? null,
            ])));
            $role = $user->access_level === 'admin' ? 'owner' : $user->access_level;

            DB::table('users')->where('id', $user->id)->update([
                'name' => $name,
                'access_level' => $role,
                'role' => $role,
                'status' => $user->is_active ? 'active' : 'inactive',
            ]);
        });

        foreach ($this->companyOwnedTables as $tableName) {
            Schema::table($tableName, function (Blueprint $table): void {
                $table->foreignId('company_id')->nullable()->constrained('companies')->nullOnDelete();
            });
        }
    }

    public function down(): void
    {
        foreach (array_reverse($this->companyOwnedTables) as $tableName) {
            Schema::table($tableName, function (Blueprint $table): void {
                $table->dropConstrainedForeignId('company_id');
            });
        }

        Schema::table('users', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('company_id');
            $table->dropColumn(['name', 'role', 'status']);
        });

        Schema::dropIfExists('companies');
    }
};
