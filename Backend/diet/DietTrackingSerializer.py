from rest_framework import serializers
from .models import DietTracking

class DietTrackingSerializer(serializers.ModelSerializer):
    class Meta:
        model = DietTracking
        fields = '__all__'
