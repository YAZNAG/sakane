<?php

namespace Database\Seeders;

use App\Models\WhatsappMessage;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class WhatsappMessageSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        WhatsappMessage::insert(
            [
                [
                    "code" => "new-booking-client",
                    "message_name" => "nouveau reservation (client)",
                    "message" => "السلام عليكم 👋
يسرّنا أن نرحّب بكم، ونشكركم على ثقتكم واختياركم الإقامة لدينا  😊
لقد تم تأكيد حجزكم بنجاح 🏠
إذا احتجتم لأي مساعدة لا تترددوا في التواصل📞📩
نتمنى لكم إقامة مريحة 🌿
Bienvenue, et merci d’avoir choisi notre logement 😊
Votre réservation a été confirmée avec succès 🏠
Si vous avez la moindre question durant votre séjour, n’hésitez pas à nous contacter 📞📩
Nous vous souhaitons un excellent séjour 🌿"
                ],
                [
                    "code" => "new-booking-admin",
                    "message_name" => "nouveau reservation (admin)",
                    "message" => "Félicitations ! Nouvelle réservation 🎉"
                ],
                [
                    "code" => "client-leaving-reminder",
                    "message_name" => "Rappel de sortie du client",
                    "message" => "السلام عليكم 👋
نتمنى أن تكون إقامتكم على ما يرام 😊
تذكير موعد المغادرة، حسب الحجز الخاص بكم، هو غدا عند الساعة 12:00  ⏰
إذا رغبتم في تمديد الإقامة، يسعدنا تواصلكم معنا قبل نهاية اليوم 📩
شكرًا لكم، ونتمنى لكم إقامة سعيدة ✨
Bonjour 👋
Nous espérons que votre séjour se passe bien 😊
Petit rappel : l’heure de départ (check-out), selon votre réservation, est demain à 12h00 ⏰
Si vous souhaitez prolonger votre séjour, merci de nous contacter avant la fin de la journée 📩
Merci et excellent séjour à vous"
                ],
                [
                    "code" => "client-leaving-reminder-manager",
                    "message_name" => "Rappel de sortie du client",
                    "message" => "Le client quittera l’appartement {{1}} demain"
                ],
            ]
        );
    }
}
