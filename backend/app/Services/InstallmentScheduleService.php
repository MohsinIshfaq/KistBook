<?php

namespace App\Services;

use App\Models\Installment;
use App\Models\InstallmentPlanItem;
use App\Models\Plan;
use Illuminate\Support\Carbon;

class InstallmentScheduleService
{
    public function rebuild(Plan $plan): void
    {
        foreach ($plan->installments()->where('paid_amount', '<=', 0)->get() as $schedule) {
            $schedule->forceFill(['is_deleted' => true])->save();
            $schedule->delete();
        }

        $nextSequence = ((int) $plan->installments()->withTrashed()->max('sequence_number')) + 1;
        if ($plan->mode === 'common') {
            $this->generateCommon($plan, $nextSequence);
        } else {
            $this->generateSeparate($plan, $nextSequence);
        }

        $paid = (float) $plan->installments()->sum('paid_amount');
        $plan->forceFill([
            'remaining_amount' => max(0, (float) $plan->total_amount - (float) $plan->deposit_amount - $paid),
            'installment_count' => $plan->installments()->count(),
        ])->save();
    }

    private function generateCommon(Plan $plan, int $nextSequence): void
    {
        $paidSchedules = $plan->installments()->where('paid_amount', '>', 0)->count();
        $remaining = max(0, (float) $plan->total_amount - (float) $plan->deposit_amount - (float) $plan->installments()->sum('paid_amount'));
        $dueDate = Carbon::parse($plan->start_date)->addDays($paidSchedules * $plan->frequency_days);
        $itemSequence = $paidSchedules + 1;

        while ($remaining > 0.009) {
            $amount = min((float) $plan->installment_amount, $remaining);
            $this->createSchedule($plan, null, 'common', $nextSequence++, $itemSequence++, $dueDate, $amount);
            $remaining -= $amount;
            $dueDate->addDays($plan->frequency_days);
        }
    }

    private function generateSeparate(Plan $plan, int $nextSequence): void
    {
        foreach ($plan->items()->get() as $item) {
            $paidSchedules = $item->schedules()->where('paid_amount', '>', 0)->count();
            $remaining = max(0, (float) $item->total_amount - (float) $item->deposit_amount - (float) $item->schedules()->sum('paid_amount'));
            $dueDate = Carbon::parse($item->first_due_date)->addDays($paidSchedules * $item->frequency_days);
            $itemSequence = $paidSchedules + 1;

            while ($remaining > 0.009) {
                $amount = min((float) $item->installment_amount, $remaining);
                $this->createSchedule($plan, $item, 'item', $nextSequence++, $itemSequence++, $dueDate, $amount);
                $remaining -= $amount;
                $dueDate->addDays($item->frequency_days);
            }
        }
    }

    private function createSchedule(
        Plan $plan,
        ?InstallmentPlanItem $item,
        string $group,
        int $sequence,
        int $itemSequence,
        Carbon $dueDate,
        float $amount,
    ): void {
        Installment::query()->create([
            'company_id' => $plan->company_id,
            'plan_uuid' => $plan->uuid,
            'plan_item_uuid' => $item?->uuid,
            'schedule_group' => $group,
            'sequence_number' => $sequence,
            'item_sequence_number' => $itemSequence,
            'scheduled_due_date' => $dueDate->toDateString(),
            'current_due_date' => $dueDate->toDateString(),
            'amount' => $amount,
            'paid_amount' => 0,
            'status' => 'pending',
            'is_deleted' => false,
        ]);
    }
}
