
from rest_framework import serializers
from .models import BloodGlucose
import pytz

class BloodGlucoseSerializer(serializers.ModelSerializer):
    created_at = serializers.SerializerMethodField()

    class Meta:
        model = BloodGlucose
        fields = [
            'id',
            'blood_glucose',
            'time_of_measurement',
            'severity',
            'predicted_glucose',
            'created_at',
        ]

    def get_created_at(self, obj):
        user_timezone = self.context.get('user_timezone', pytz.UTC)
        return obj.created_at.astimezone(user_timezone).isoformat()
