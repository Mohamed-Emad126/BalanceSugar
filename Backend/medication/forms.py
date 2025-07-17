from django import forms
from .models import Medication

class MedicationForm(forms.ModelForm):
    class Meta:
        model = Medication
        fields = [
          'medication_name', 
            'route_of_administration', 
            'dosage_form', 
            'dosage_unit_of_measure', 
            'dosage_quantity_of_units_per_time',
            'equally_distributed_regimen', 
            'dosage_frequency', 
            'periodic_interval', 
            'first_time_of_intake', 
            'is_chronic_or_acute', 
            'stopped_by_datetime',
            'interaction_warning',
        ]
        widgets = {
            'first_time_of_intake': forms.DateTimeInput(attrs={'type': 'datetime-local'}),
            'stopped_by_datetime': forms.DateTimeInput(attrs={'type': 'datetime-local'}),
        }

    def clean(self):
        cleaned_data = super().clean()
        first_time = cleaned_data.get('first_time_of_intake')
        stopped_time = cleaned_data.get('stopped_by_datetime')
        
        # Ensure stopped time is not before first intake time if provided
        if stopped_time and stopped_time < first_time:
            raise forms.ValidationError("Stopped time cannot be before first intake time.")

        return cleaned_data






















# from django import forms
# from .models import Medication
# from django.core.exceptions import ValidationError
# from django.utils import timezone

# class MedicationForm(forms.ModelForm):
#     class Meta:
#         model = Medication
#         fields = [
#             'medication_name',
#             'route_of_administration',
#             'dosage_unit_of_measure',
#             'dosage_quantity',
#             'dosage_frequency',
#             'periodic_interval',
#             'start_date',
#             'end_date',
#             'reminder_times',
#         ]
#         widgets = {
#             'start_date': forms.DateTimeInput(attrs={'type': 'datetime-local'}),
#             'end_date': forms.DateTimeInput(attrs={'type': 'datetime-local'}),
#             'reminder_times': forms.TextInput(attrs={'placeholder': 'e.g., 08:00, 20:00'}),
#         }

#     def clean_reminder_times(self):
#         """
#         Validate and clean the reminder_times field.
#         Ensure it's a list of valid times in HH:MM format.
#         """
#         reminder_times = self.cleaned_data.get('reminder_times')
#         if reminder_times:
#             try:
#                 times = [time.strip() for time in reminder_times.split(',')]
#                 for time in times:
#                     if not time or len(time) != 5 or time[2] != ':':
#                         raise forms.ValidationError("Please enter times in HH:MM format, separated by commas.")
#                     hours, minutes = map(int, time.split(':'))
#                     if hours < 0 or hours > 23 or minutes < 0 or minutes > 59:
#                         raise forms.ValidationError("Invalid time. Hours must be between 0-23 and minutes between 0-59.")
#                 return times
#             except ValueError:
#                 raise forms.ValidationError("Invalid time format. Please use HH:MM.")
#         return []

#     def clean(self):
#         """
#         Validate the form data, including start and end date comparison.
#         """
#         cleaned_data = super().clean()
#         start_date = cleaned_data.get('start_date')
#         end_date = cleaned_data.get('end_date')

#         if end_date and end_date < start_date:
#             raise forms.ValidationError("End date cannot be before start date.")

#         # Ensure dosage frequency is valid (non-zero)
#         dosage_frequency = cleaned_data.get('dosage_frequency')
#         if dosage_frequency <= 0:
#             raise forms.ValidationError("Dosage frequency must be a positive number.")

#         return cleaned_data


















# from django import forms
# from .models import Medication
# from django.utils import timezone

# class MedicationForm(forms.ModelForm):
#     class Meta:
#         model = Medication
#         fields = [
#             'medication_name',
#             'route_of_administration',
#             'dosage_unit_of_measure',
#             'dosage_quantity',
#             'dosage_frequency',
#             'periodic_interval',
#             'start_date',
#             'end_date',
#             'reminder_times',
#         ]
#         widgets = {
#             'start_date': forms.DateTimeInput(attrs={'type': 'datetime-local'}),
#             'end_date': forms.DateTimeInput(attrs={'type': 'datetime-local'}),
#             'reminder_times': forms.TextInput(attrs={'placeholder': 'e.g., 08:00, 20:00'}),
#         }

#     def clean_reminder_times(self):
#         """
#         Validate and clean the reminder_times field.
#         Ensure it's a list of valid times in HH:MM format.
#         """
#         reminder_times = self.cleaned_data.get('reminder_times')
#         if reminder_times:
#             try:
#                 times = [time.strip() for time in reminder_times.split(',')]
#                 for time in times:
#                     if not time or len(time) != 5 or time[2] != ':':
#                         raise forms.ValidationError("Please enter times in HH:MM format, separated by commas.")
#                     hours, minutes = map(int, time.split(':'))
#                     if hours < 0 or hours > 23 or minutes < 0 or minutes > 59:
#                         raise forms.ValidationError("Invalid time. Hours must be between 0-23 and minutes between 0-59.")
#                 return times
#             except ValueError:
#                 raise forms.ValidationError("Invalid time format. Please use HH:MM.")
#         return []

#     def clean(self):
#         """
#         Validate the form data.
#         """
#         cleaned_data = super().clean()
#         start_date = cleaned_data.get('start_date')
#         end_date = cleaned_data.get('end_date')

#         if end_date and end_date < start_date:
#             raise forms.ValidationError("End date cannot be before start date.")

#         return cleaned_data