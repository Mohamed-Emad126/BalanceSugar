from django.db import models
from accounts.models import User
from django.utils import timezone

class Medication(models.Model):
    ROUTE_CHOICES = (
        ('oral', 'Orally'),
        ('parentral/im', 'Intra-muscular'),
        ('parentral/iv', 'Intravenous'),
        ('parentral/sc', 'Subcutaneous'),
    )

    UNIT_CHOICES = (
        ('tablet', 'Tablet'),
        ('capsule', 'Capsule'),
        ('gravimetric/mg', 'Milligram (mg)'),
        ('volumetric/ml', 'Milliliter/ml'),
    )

    INTERVAL_CHOICES = (
        ('daily', 'Daily'),
        ('weekly', 'Weekly'),
        ('monthly', 'Monthly'),
    )
    
    FORM_DOSAGE = (
        ('tablet', 'Tablet'), 
        ('capsule', 'Capsule'), 
        ('syrup', 'Syrup'), 
        ('injectable', 'Injectable')
    )
    
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='medications')
    medication_name = models.CharField(max_length=100, help_text="Generic name of the medication")
    route_of_administration = models.CharField(max_length=50, choices=ROUTE_CHOICES, default='oral')
    dosage_form = models.CharField(max_length=50, choices=FORM_DOSAGE, default='syrup')
    dosage_unit_of_measure = models.CharField(max_length=50, choices=UNIT_CHOICES, default='tablet')
    dosage_quantity_of_units_per_time = models.FloatField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    interaction_warning = models.CharField(max_length=512, null=True, blank=True)
    equally_distributed_regimen = models.BooleanField(default=True, null=True, blank=False)
    dosage_frequency = models.PositiveIntegerField()
    periodic_interval = models.CharField(max_length=20, choices=INTERVAL_CHOICES, default='daily')
    first_time_of_intake = models.DateTimeField(default=timezone.now)
    stopped_by_datetime = models.DateTimeField(null=True, blank=True)
    
    
    def __str__(self):
        return self.medication_name
    
    def calculate_next_dose(self):
        """
        Calculate the next dose based on the first time of intake and the periodic interval.
        """
        if self.periodic_interval == 'daily':
            return self.first_time_of_intake + timezone.timedelta(days=self.dosage_frequency)
        elif self.periodic_interval == 'weekly':
            return self.first_time_of_intake + timezone.timedelta(weeks=self.dosage_frequency)
        elif self.periodic_interval == 'monthly':
            return self.first_time_of_intake + timezone.timedelta(weeks=4 * self.dosage_frequency)
        return self.first_time_of_intake
    


    

