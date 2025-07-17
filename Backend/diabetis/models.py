from django.db import models
from accounts.models import User
from django.utils import timezone
# Create your models here.


TIME_CHOICES = [
    ("Pre-Breakfast", "Pre-Breakfast"),
    ("Post-Breakfast", "Post-Breakfast"),
    ("Pre-Lunch", "Pre-Lunch"),
    ("Post-Lunch", "Post-Lunch"),
    ("Pre-Dinner", "Pre-Dinner"),
    ("Post-Dinner", "Post-Dinner"),
    ("Random", "Random"),
]


class BloodGlucose(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    blood_glucose = models.FloatField()
    time_of_measurement = models.CharField(max_length=20, choices=TIME_CHOICES)
    severity = models.CharField(max_length=50)
    predicted_glucose = models.FloatField()
    created_at = models.DateTimeField(default=timezone.now)
    
    def __str__(self):
        return f"{self.user} - {self.blood_glucose} - {self.time_of_measurement} - {self.severity} - {self.predicted_glucose}"
    
    class Meta:
        ordering = ['-created_at']