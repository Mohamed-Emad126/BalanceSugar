
from rest_framework import serializers
from .models import FootUlcer
from django.conf import settings

    
class FootUlcerSerializer(serializers.ModelSerializer):
    segmented_image_url = serializers.SerializerMethodField()
    image_url = serializers.SerializerMethodField()
    
    class Meta:
        model = FootUlcer
        fields = ['id', 'user', 'image','region', 'image_url', 'classification_result', 'confidence', 'segmented_image', 'segmented_image_url', 'ulcer_area', 'last_area', 'area_difference', 'improvement_message', 'uploaded_at']
    
    def get_image_url(self, obj):
        request = self.context.get('request')
        if obj.image:
            return request.build_absolute_uri(obj.image.url) if request else obj.image.url
        return None

    def get_segmented_image_url(self, obj):
        request = self.context.get('request')
        if obj.segmented_image:
            return request.build_absolute_uri(obj.segmented_image.url) if request else obj.segmented_image.url
        return None

