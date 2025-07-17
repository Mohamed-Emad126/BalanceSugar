#medication/serializers.py
from rest_framework import serializers
from .models import Medication
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
import pytz
from django.utils import timezone

class ReminderTokenSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        # because there is a field in the reminder model that link it to the respective user, one can access fields of reminder by going through the keys of dictionary
        token['id'] = user.reminder_user.id
        token['medicine_name'] = user.reminder_user.medicine_name
        token['route_of_administration'] = user.reminder_user.route_of_administration
        token['dosage_form'] = user.reminder_user.dosage_form
        token['dosage_quantity_of_units_per_time'] = user.reminder_user.dosage_quantity_of_units_per_time
        token['periodic_interval'] = user.reminder_user.periodic_interval
        token['dosage_frequency'] = user.reminder_user.dosage_frequency
        token['first_time_of_intake'] = user.reminder_user.first_time_of_intake
        token['stopped_by_datetime'] = user.reminder_user.stopped_by_datetime
        token['interaction_warning'] = user.reminder_user.interaction_warning


class MedicationSerializer(serializers.ModelSerializer):
    first_time_of_intake = serializers.SerializerMethodField()
    stopped_by_datetime = serializers.SerializerMethodField()

    class Meta:
        model = Medication
        fields = [
            'id',
            'medication_name',
            'route_of_administration',
            'dosage_form',
            'dosage_unit_of_measure',
            'dosage_quantity_of_units_per_time',
            'equally_distributed_regimen',
            'periodic_interval',
            'dosage_frequency',
            'first_time_of_intake',
            'stopped_by_datetime',
            'interaction_warning',
        ]

    def get_first_time_of_intake(self, obj):
        user_timezone = self.context.get('user_timezone', pytz.UTC)

        dt = obj.first_time_of_intake

        if dt is None:
            return None

        if isinstance(dt, str):
            dt = parse_datetime(dt)
        
        if not isinstance(dt, timezone.datetime):  # failed to parse or still invalid
            return None

        return dt.astimezone(user_timezone).isoformat()

    def get_stopped_by_datetime(self, obj):
        user_timezone = self.context.get('user_timezone', pytz.UTC)

        dt = obj.stopped_by_datetime

        if dt is None:
            return None

        if isinstance(dt, str):
            dt = parse_datetime(dt)
        
        if not isinstance(dt, timezone.datetime):  # failed to parse or still invalid
            return None

        return dt.astimezone(user_timezone).isoformat()
    def validate_medication_name(self, value):
        if not value:
            raise serializers.ValidationError("Medication name cannot be empty.")
        return value

    def validate_dosage_quantity_of_units_per_time(self, value):
        if value <= 0:
            raise serializers.ValidationError("Dosage quantity must be a positive number.")
        return value

