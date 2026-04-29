<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class RegistrationRejectedMail extends Mailable
{
    use Queueable, SerializesModels;

    public $reason;
    public $name;

    /**
     * Create a new message instance.
     */
    public function __construct($name, $reason = null)
    {
        $this->name = $name;
        $this->reason = $reason ?? 'Data profil tidak sesuai dengan standar perusahaan.';
    }

    /**
     * Get the message envelope.
     */
    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Pendaftaran Akun SapaHSE Ditolak',
        );
    }

    /**
     * Get the message content definition.
     */
    public function content(): Content
    {
        return new Content(
            view: 'emails.registration-rejected',
        );
    }
}