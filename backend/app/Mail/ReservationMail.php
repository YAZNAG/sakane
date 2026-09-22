<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class ReservationMail extends Mailable
{
    use Queueable, SerializesModels;

    public $title;
    public $subtitle;
    public $checkin;
    public $checkout;
    public $guest;
    public $amount;
    public $subjectText;

    public function __construct($title,$subtitle,$checkin,$checkout,$guest,$amount,$subject)
    {
        $this->title=$title;
        $this->subtitle=$subtitle;
        $this->checkin=$checkin;
        $this->checkout=$checkout;
        $this->guest=$guest;
        $this->amount=$amount;
        $this->subjectText=$subject;
    }




    public function envelope(): Envelope
    {
        return new Envelope(
            subject: $this->subjectText,
        );
    }

    /**
     * Get the message content definition.
     */
    public function content(): Content
    {
        return new Content(
            view: 'emails.reservation',
        );
    }

    /**
     * Get the attachments for the message.
     *
     * @return array<int, \Illuminate\Mail\Mailables\Attachment>
     */
    public function attachments(): array
    {
        return [];
    }
}
