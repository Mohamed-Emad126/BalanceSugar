from django.utils import timezone
import datetime
from datetime import timedelta

def get_todays_scheduled_doses(medication, today_start, today_end):
    """
    Calculate all scheduled doses for a medication within a given timeframe.
    Assumes doses are equally distributed throughout the day.
    All calculations are done in UTC, and the function expects timezone-aware datetimes.
    """
    doses = []
    
    # Skip if medication has no dosage frequency
    if not medication.dosage_frequency or medication.dosage_frequency <= 0:
        return doses
    
    # Get the base interval in minutes
    if medication.periodic_interval.lower() == 'daily':
        interval_minutes = 24 * 60  # 1440 minutes
    elif medication.periodic_interval.lower() == 'weekly':
        interval_minutes = 7 * 24 * 60  # 10080 minutes
    elif medication.periodic_interval.lower() == 'monthly':
        interval_minutes = 30 * 24 * 60  # 43200 minutes (approximate)
    else:
        return doses
    
    # Calculate time between doses (equally distributed)
    dose_spacing_minutes = interval_minutes / medication.dosage_frequency
    
    # Find the medication's first intake time (it's already in UTC)
    first_intake = medication.first_time_of_intake

    # The start and end times are already in UTC, no need for conversion.
    
    # Calculate how many complete intervals have passed since first intake
    time_since_first = (today_start - first_intake).total_seconds() / 60  # in minutes
    
    if time_since_first < 0:
        # Medication starts in the future, check if it starts today
        if first_intake <= today_end:
            # Calculate doses starting from first_intake
            for i in range(medication.dosage_frequency):
                dose_time = first_intake + timedelta(minutes=i * dose_spacing_minutes)
                if today_start <= dose_time < today_end:
                    doses.append(dose_time)
    else:
        # Medication started in the past, calculate today's doses
        complete_intervals = int(time_since_first // interval_minutes)
        
        # Calculate the start of the current interval cycle
        current_cycle_start = first_intake + timedelta(minutes=complete_intervals * interval_minutes)
        
        # Generate doses for the current cycle that fall within today
        for i in range(medication.dosage_frequency):
            dose_time = current_cycle_start + timedelta(minutes=i * dose_spacing_minutes)
            if today_start <= dose_time < today_end:
                doses.append(dose_time)
        
        # Also check if the next cycle starts today
        next_cycle_start = current_cycle_start + timedelta(minutes=interval_minutes)
        if next_cycle_start < today_end:
            for i in range(medication.dosage_frequency):
                dose_time = next_cycle_start + timedelta(minutes=i * dose_spacing_minutes)
                if today_start <= dose_time < today_end:
                    doses.append(dose_time)
    
    # Filter out doses that are after the medication was stopped
    if medication.stopped_by_datetime:
        stopped_time = medication.stopped_by_datetime
        doses = [dose for dose in doses if dose <= stopped_time]
    
    return sorted(doses)