from django.db import models
from accounts.models import User


class FootUlcer(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="footcare")  # Link directly to User
    image = models.ImageField(upload_to="uploads/")
    uploaded_at = models.DateTimeField(auto_now_add=True)
    classification_result = models.CharField(max_length=50 , null = True , blank = True)
    confidence = models.FloatField(null=True, blank=True)
    region = models.CharField(max_length=50 ,  null = False , blank= False)
    segmented_image = models.ImageField(upload_to="uploads/segmented/", null=True, blank=True)
    ulcer_area = models.FloatField(null=True, blank=True)
    last_area = models.FloatField(null=True, blank=True)
    area_difference = models.FloatField(null=True, blank=True)
    improvement_message = models.CharField(max_length=255, null=True, blank=True)

    def __str__(self):
        return f"{self.user.email} - {self.classification_result}"

