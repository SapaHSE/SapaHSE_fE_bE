<?php

namespace App\Mail\Transport;

use Illuminate\Support\Facades\Http;
use Symfony\Component\Mailer\Envelope;
use Symfony\Component\Mailer\Exception\TransportException;
use Symfony\Component\Mailer\SentMessage;
use Symfony\Component\Mailer\Transport\AbstractTransport;
use Symfony\Component\Mime\Address;
use Symfony\Component\Mime\Email;
use Symfony\Component\Mime\MessageConverter;

class BrevoTransport extends AbstractTransport
{
    private const API_ENDPOINT = 'https://api.brevo.com/v3/smtp/email';

    public function __construct(private string $apiKey)
    {
        parent::__construct();
    }

    protected function doSend(SentMessage $message): void
    {
        $email    = MessageConverter::toEmail($message->getOriginalMessage());
        $envelope = $message->getEnvelope();

        $payload = [
            'sender'      => $this->formatSender($envelope),
            'to'          => $this->formatAddresses($this->getToRecipients($email, $envelope)),
            'subject'     => $email->getSubject() ?? '(no subject)',
            'htmlContent' => $email->getHtmlBody() ?? $this->wrapTextAsHtml($email->getTextBody()),
            'textContent' => $email->getTextBody() ?? strip_tags((string) $email->getHtmlBody()),
        ];

        if ($cc = $email->getCc()) {
            $payload['cc'] = $this->formatAddresses($cc);
        }

        if ($bcc = $email->getBcc()) {
            $payload['bcc'] = $this->formatAddresses($bcc);
        }

        if ($replyTo = $email->getReplyTo()) {
            $payload['replyTo'] = $this->formatSingleAddress($replyTo[0]);
        }

        $attachments = [];
        foreach ($email->getAttachments() as $i => $attachment) {
            $attachments[] = [
                'name'    => $attachment->getFilename() ?? ('attachment_' . ($i + 1)),
                'content' => base64_encode($attachment->getBody()),
            ];
        }
        if ($attachments) {
            $payload['attachment'] = $attachments;
        }

        try {
            $response = Http::withHeaders([
                'Accept'       => 'application/json',
                'Content-Type' => 'application/json',
                'api-key'      => $this->apiKey,
            ])->timeout(30)->post(self::API_ENDPOINT, $payload);

            if ($response->failed()) {
                throw new TransportException(
                    'Brevo API error (' . $response->status() . '): ' . $response->body(),
                    $response->status()
                );
            }

            $responseData = $response->json();
            if (isset($responseData['messageId'])) {
                $message->setMessageId($responseData['messageId']);
            }
        } catch (TransportException $e) {
            throw $e;
        } catch (\Throwable $e) {
            throw new TransportException('Brevo transport failed: ' . $e->getMessage(), 0, $e);
        }
    }

    private function formatSender(Envelope $envelope): array
    {
        $sender = $envelope->getSender();
        $name   = $sender->getName() ?: config('mail.from.name', 'SapaHSE');

        return ['name' => $name, 'email' => $sender->getAddress()];
    }

    /** @param Address[] $addresses */
    private function formatAddresses(array $addresses): array
    {
        return array_map(function (Address $a) {
            $entry = ['email' => $a->getAddress()];
            if ($name = $a->getName()) {
                $entry['name'] = $name;
            }
            return $entry;
        }, $addresses);
    }

    private function formatSingleAddress(Address $address): array
    {
        $entry = ['email' => $address->getAddress()];
        if ($name = $address->getName()) {
            $entry['name'] = $name;
        }
        return $entry;
    }

    /** @return Address[] */
    private function getToRecipients(Email $email, Envelope $envelope): array
    {
        $ccBcc = array_merge($email->getCc(), $email->getBcc());

        return array_values(array_filter(
            $envelope->getRecipients(),
            fn(Address $address) => !in_array($address, $ccBcc, true)
        ));
    }

    private function wrapTextAsHtml(?string $text): ?string
    {
        if ($text === null) {
            return null;
        }
        return '<pre>' . htmlspecialchars($text, ENT_QUOTES, 'UTF-8') . '</pre>';
    }

    public function __toString(): string
    {
        return 'brevo';
    }
}
