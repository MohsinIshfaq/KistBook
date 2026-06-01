<?php

namespace App\Providers;

use App\Contracts\Repositories\CustomerRepositoryInterface;
use App\Contracts\Repositories\InstallmentRepositoryInterface;
use App\Contracts\Repositories\PaymentRepositoryInterface;
use App\Contracts\Repositories\PlanRepositoryInterface;
use App\Contracts\Repositories\ProductCategoryRepositoryInterface;
use App\Contracts\Repositories\ProductRepositoryInterface;
use App\Contracts\Repositories\UserCustomerAccessRepositoryInterface;
use App\Contracts\Repositories\UserPlanAccessRepositoryInterface;
use App\Contracts\Repositories\UserRepositoryInterface;
use App\Contracts\Services\AccessServiceInterface;
use App\Contracts\Services\AuthServiceInterface;
use App\Contracts\Services\CustomerServiceInterface;
use App\Contracts\Services\DashboardServiceInterface;
use App\Contracts\Services\InstallmentServiceInterface;
use App\Contracts\Services\PaymentServiceInterface;
use App\Contracts\Services\PlanServiceInterface;
use App\Contracts\Services\ProductCategoryServiceInterface;
use App\Contracts\Services\ProductServiceInterface;
use App\Repositories\CustomerRepository;
use App\Repositories\InstallmentRepository;
use App\Repositories\PaymentRepository;
use App\Repositories\PlanRepository;
use App\Repositories\ProductCategoryRepository;
use App\Repositories\ProductRepository;
use App\Repositories\UserCustomerAccessRepository;
use App\Repositories\UserPlanAccessRepository;
use App\Repositories\UserRepository;
use App\Services\AccessService;
use App\Services\AuthService;
use App\Services\CustomerService;
use App\Services\DashboardService;
use App\Services\InstallmentService;
use App\Services\PaymentService;
use App\Services\PlanService;
use App\Services\ProductCategoryService;
use App\Services\ProductService;
use App\Models\Customer;
use App\Policies\CustomerPolicy;
use Illuminate\Support\Facades\Gate;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->bind(UserRepositoryInterface::class, UserRepository::class);
        $this->app->bind(CustomerRepositoryInterface::class, CustomerRepository::class);
        $this->app->bind(ProductRepositoryInterface::class, ProductRepository::class);
        $this->app->bind(ProductCategoryRepositoryInterface::class, ProductCategoryRepository::class);
        $this->app->bind(PlanRepositoryInterface::class, PlanRepository::class);
        $this->app->bind(InstallmentRepositoryInterface::class, InstallmentRepository::class);
        $this->app->bind(PaymentRepositoryInterface::class, PaymentRepository::class);
        $this->app->bind(UserCustomerAccessRepositoryInterface::class, UserCustomerAccessRepository::class);
        $this->app->bind(UserPlanAccessRepositoryInterface::class, UserPlanAccessRepository::class);

        $this->app->bind(AuthServiceInterface::class, AuthService::class);
        $this->app->bind(CustomerServiceInterface::class, CustomerService::class);
        $this->app->bind(ProductServiceInterface::class, ProductService::class);
        $this->app->bind(ProductCategoryServiceInterface::class, ProductCategoryService::class);
        $this->app->bind(PlanServiceInterface::class, PlanService::class);
        $this->app->bind(InstallmentServiceInterface::class, InstallmentService::class);
        $this->app->bind(PaymentServiceInterface::class, PaymentService::class);
        $this->app->bind(AccessServiceInterface::class, AccessService::class);
        $this->app->bind(DashboardServiceInterface::class, DashboardService::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        JsonResource::withoutWrapping();
        Gate::policy(Customer::class, CustomerPolicy::class);
    }
}
