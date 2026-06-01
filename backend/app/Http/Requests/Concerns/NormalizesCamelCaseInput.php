<?php

namespace App\Http\Requests\Concerns;

trait NormalizesCamelCaseInput
{
    /**
     * @param  array<string, string>  $aliases
     */
    protected function mergeCamelCaseAliases(array $aliases): void
    {
        $normalized = [];

        foreach ($aliases as $internal => $public) {
            if (! $this->has($internal) && $this->has($public)) {
                $normalized[$internal] = $this->input($public);
            }
        }

        $this->merge($normalized);
    }
}
