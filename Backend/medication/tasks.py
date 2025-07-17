from celery import shared_task
from pyfcm import FCMNotification
from django.utils.timezone import now
from .models import MedicationManagement, Device
import datetime

# Initialize Firebase Cloud Messaging with your server key
push_service = FCMNotification(api_key="BAeYsgCQ0EQDzykkwnkqDcx7mvbnyWNahKH7ldYiiIwnwkKjqAVJnr6lrH5kyrFa4rTv24t9uOsEeS9KwvXGy5c")


@shared_task
def send_medication_notifications():
    """
    Send push notifications to users with due medication reminders.
    """
    # Get the current time
    current_time = now()

    # Fetch reminders due for the next dose
    reminders = MedicationManagement.objects.filter(
        stopped_by_datetime__isnull=True,  # Ensure medication is still active
        first_time_of_intake__lte=current_time  # Intake time should have started
    )

    for reminder in reminders:
        # Calculate the next dose time
        time_since_first = (current_time - reminder.first_time_of_intake).total_seconds()
        interval_seconds = {
            'daily': 24 * 60 * 60,       # Daily reminders
            'weekly': 7 * 24 * 60 * 60,  # Weekly reminders
            'monthly': 30 * 24 * 60 * 60, # Monthly reminders
        }.get(reminder.periodic_interval, 0)

        # Check if it's time for the next dose
        if interval_seconds > 0 and time_since_first % interval_seconds < 60:
            # Fetch all device tokens for the user
            devices = Device.objects.filter(user=reminder.user)

            for device in devices:
                # Send push notification to the user's device
                push_service.notify_single_device(
                    registration_id=device.device_token,
                    message_title="Medication Reminder",
                    message_body=f"It's time to take your medication: {reminder.medicine_name}."
                )

            # Optional: Log the notification for debugging or auditing
            print(f"Notification sent: {reminder.medicine_name} for {reminder.user.username}")

