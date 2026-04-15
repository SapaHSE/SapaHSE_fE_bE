<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class BrevoEmailService
{
    public function sendEmail(array $to, string $subject, string $htmlContent, ?string $textContent = null): bool
    {
        $apiKey = config('mail.mailers.brevo.api_key');

        if (!$apiKey) {
            Log::error('Brevo API key not configured');
            return false;
        }

        $payload = [
            'sender' => [
                'name' => config('mail.from.name', 'SapaHSE'),
                'email' => config('mail.from.address'),
            ],
            'to' => array_map(fn($email) => is_array($email) ? $email['email'] : $email, $to),
            'subject' => $subject,
            'htmlContent' => $htmlContent,
            'textContent' => $textContent ?? strip_tags($htmlContent),
        ];

        try {
            $response = Http::withHeaders([
                'Accept' => 'application/json',
                'Content-Type' => 'application/json',
                'api-key' => $apiKey,
            ])->timeout(30)->post('https://api.brevo.com/v3/smtp/email', $payload);

            if ($response->failed()) {
                Log::error('Brevo API error: ' . $response->body());
                return false;
            }

            return true;
        } catch (\Exception $e) {
            Log::error('Brevo send error: ' . $e->getMessage());
            return false;
        }
    }
}