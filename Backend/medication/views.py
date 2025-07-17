#medication/view.py

from django.http import JsonResponse
from .models import Medication
from .serializers import MedicationSerializer
from drf_yasg.utils import swagger_auto_schema
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from django.conf import settings
import joblib
import numpy as np
import json
from drf_yasg import openapi
from django.db.models import Q
from django.utils import timezone
from datetime import timedelta, time ,datetime
from dateutil import parser
from .utils import get_todays_scheduled_doses
import pytz

#Load model and matrices
clf = joblib.load(settings.DRUG_INTERACTION_MODEL_PATH)
u = np.load(settings.U_MATRIX_PATH)
vt = np.load(settings.VT_MATRIX_PATH)
drug_index = np.load(settings.DRUG_INDEX_PATH, allow_pickle=True).item()

# Severity Mapping for drug interactions
severity_messages = {
    3: "Major interaction: Serious side effects may occur. Consult a healthcare provider.",
    2: "Moderate interaction: Potential interactions. Seek medical advice if needed.",
    1: "Minor interaction: Minimal effects expected.",
    0: "No known interaction."
}

# Function to preprocess input data for drug interaction prediction
def preprocess_input(drug_a, drug_b):
    """Prepare input features for prediction."""
    idx1 = drug_index.get(drug_a)
    idx2 = drug_index.get(drug_b)
    if idx1 is None or idx2 is None:
        return None
    return np.concatenate([u[idx1], vt[idx2]])

# Function to predict the severity of a drug interaction
def predict_interaction(drug_a, drug_b):
    """Predict severity of drug interaction."""
    features = preprocess_input(drug_a, drug_b)
    if features is None:
        return None
    severity_prediction = clf.predict([features])[0]
    return severity_messages.get(severity_prediction, "Unknown interaction level.")

# Function to format medication name
def format_medication_name(name):
    return name.strip().lower().capitalize() if name else name


def parse_datetime_safe(raw_value):
    if not raw_value:
        return None
    
    try:
        dt = parser.isoparse(raw_value)
        if timezone.is_naive(dt):
            # If naive, assume UTC
            return timezone.make_aware(dt, pytz.UTC)
        # If aware, convert to UTC
        return dt.astimezone(pytz.UTC)
    except ValueError:
        return None

# 1. Function to create a new medication entry and check for interactions with existing medications
@swagger_auto_schema(method='post', request_body=MedicationSerializer, responses={201: MedicationSerializer, 400: 'Bad Request'})
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_medication(request):
    data = request.data
    medication_name = format_medication_name(data.get('medication_name'))
    
    if not medication_name:
        return Response({"error": "Medication name is required."}, status=400)

    # Check interactions with existing medications
    interaction_warnings = {}

    current_time = timezone.now()
    
    existing_medications = Medication.objects.filter(
        user=request.user
    ).filter(
        Q(stopped_by_datetime__gte=current_time) | Q(stopped_by_datetime__isnull=True)
    )
    
    for med in existing_medications:
        existing_med_name = format_medication_name(med.medication_name)
        interaction_result = predict_interaction(existing_med_name, medication_name)
        if interaction_result:
            interaction_warnings[med.medication_name] = interaction_result

    first_time = parse_datetime_safe(data.get('first_time_of_intake'))
    stopped_time = parse_datetime_safe(data.get('stopped_by_datetime'))

    medication = Medication.objects.create(
        user=request.user,
        medication_name=medication_name,
        route_of_administration=data.get('route_of_administration', 'oral'),
        dosage_form=data.get('dosage_form', 'tablet'),
        dosage_unit_of_measure=data.get('dosage_unit_of_measure', 'tablet'),
        dosage_quantity_of_units_per_time=data.get('dosage_quantity_of_units_per_time', 1),
        equally_distributed_regimen=True,
        periodic_interval=data.get('periodic_interval', 'daily'),
        dosage_frequency=data.get('dosage_frequency', 1),
        first_time_of_intake=first_time,
        stopped_by_datetime=stopped_time,
        interaction_warning=interaction_warnings,
    )

    serializer = MedicationSerializer(medication)
    return Response(serializer.data, status=201)

# 2. Function to update an existing medication entry and check for interactions with other medications
@swagger_auto_schema(method='put', request_body=MedicationSerializer, responses={200: MedicationSerializer, 400: 'Bad Request', 404: 'Not Found'})
@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_medication(request, primary_key):
    """Update an existing medication."""
    try:
        medication = Medication.objects.get(id=primary_key, user=request.user)
    except Medication.DoesNotExist:
        return Response({"error": "Medication not found."}, status=404)

    data = request.data
    medication_name = format_medication_name(data.get('medication_name', medication.medication_name))

    # Check interactions
    interaction_warnings = {}
    current_time = timezone.now()
    existing_medications = Medication.objects.filter(
        user=request.user
    ).filter(
        Q(stopped_by_datetime__gte=current_time) | Q(stopped_by_datetime__isnull=True)
    )

    for med in existing_medications:
        interaction_result = predict_interaction(med.medication_name, medication_name)
        if interaction_result:
            interaction_warnings[med.medication_name] = interaction_result

    # Parse datetime fields safely using your function
    first_time = parse_datetime_safe(data.get('first_time_of_intake'))
    stopped_time = parse_datetime_safe(data.get('stopped_by_datetime'))

    # Update medication fields
    medication.medication_name = medication_name
    medication.route_of_administration = data.get('route_of_administration', medication.route_of_administration)
    medication.dosage_form = data.get('dosage_form', medication.dosage_form)
    medication.dosage_unit_of_measure = data.get('dosage_unit_of_measure', medication.dosage_unit_of_measure)
    medication.dosage_quantity_of_units_per_time = data.get('dosage_quantity_of_units_per_time', medication.dosage_quantity_of_units_per_time)
    medication.equally_distributed_regimen = data.get('equally_distributed_regimen', medication.equally_distributed_regimen)
    medication.periodic_interval = data.get('periodic_interval', medication.periodic_interval)
    medication.dosage_frequency = data.get('dosage_frequency', medication.dosage_frequency)
    medication.first_time_of_intake = first_time or medication.first_time_of_intake
    medication.stopped_by_datetime = stopped_time or medication.stopped_by_datetime
    medication.interaction_warning = interaction_warnings

    medication.save()

    serializer = MedicationSerializer(medication, context={'user_timezone': request.user_timezone})
    return Response(serializer.data, status=200)


# 3. Function to retrieve all medications for the authenticated user
@swagger_auto_schema(method='get', responses={200: MedicationSerializer(many=True)})
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_medications(request):
    """Retrieve all medications for the authenticated user."""
    medications = Medication.objects.filter(user=request.user)
    serializer = MedicationSerializer(medications, many=True,context={'user_timezone': request.user_timezone})
    return Response(serializer.data)


# 4. Function to retrieve a specific medication entry for the authenticated user
@swagger_auto_schema(method='get', responses={200: MedicationSerializer})
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_medication(request, primary_key):
    """Retrieve a specific medication."""
    try:
        medication = Medication.objects.get(id=primary_key, user=request.user )
    except Medication.DoesNotExist:
        return Response({"error": "Medication not found."}, status=404)
    
    serializer = MedicationSerializer(medication ,context={'user_timezone': request.user_timezone})
    return Response(serializer.data)

# 5. Function to retrieve all active medications for the authenticated user
@swagger_auto_schema(method='get', responses={200: MedicationSerializer(many=True)})
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_active_medications(request):
    """Retrieve all active medications for the authenticated user."""
    # Get current time
    user_tz = request.user_timezone
    current_time = timezone.now().astimezone(user_tz)

    # Filter medications where stopped_by_datetime is None or in the future
    active_medications = Medication.objects.filter(
        user=request.user
    ).filter(
        Q(stopped_by_datetime__gte=current_time) | Q(stopped_by_datetime__isnull=True)
    )
    
    serializer = MedicationSerializer(active_medications, many=True ,context={'user_timezone': request.user_timezone})
    return Response(serializer.data)


# 6. Function to delete a medication entry for the authenticated user
@swagger_auto_schema(method='delete', responses={204: 'No Content'})
@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_medication(request, primary_key):
    """Delete a medication."""
    try:
        medication = Medication.objects.get(id=primary_key, user=request.user)
    except Medication.DoesNotExist:
        return Response({"error": "Medication not found."}, status=404)

    medication.delete()
    return Response({"message": "Medication deleted successfully."}, status=204)

@swagger_auto_schema(method='get', responses={200: 'List of upcoming medications for a specific day'})
@api_view(['GET'])
def get_medications_on_day(request):
    date_str = request.query_params.get('date')
    if not date_str:
        return Response({'error': 'Date parameter is required'}, status=400)

    try:
        # Parse the date safely
        date = datetime.strptime(date_str, '%Y-%m-%d')
    except ValueError:
        return Response({'error': 'Invalid date format. Use YYYY-MM-DD.'}, status=400)

    medications = Medication.objects.filter(user=request.user).filter(
        Q(first_time_of_intake__lte=date) & Q(stopped_by_datetime__gte=date)
    )
    serializer = MedicationSerializer(medications, many=True)
    return Response(serializer.data)



upcoming_medication_response = openapi.Schema(
    type=openapi.TYPE_OBJECT,
    properties={
        'medication_name': openapi.Schema(type=openapi.TYPE_STRING, description='Name of the medication'),
        'route_of_administration': openapi.Schema(type=openapi.TYPE_STRING, description='How the medication is taken'),
        'dosage_form': openapi.Schema(type=openapi.TYPE_STRING, description='Form of the medication'),
        'dosage_quantity_of_units_per_time': openapi.Schema(type=openapi.TYPE_NUMBER, description='Quantity per dose'),
        'time_for_intake': openapi.Schema(type=openapi.TYPE_STRING, description='Time to take medication (12-hour format)'),
    }
)

@swagger_auto_schema(
    method='get', 
    responses={
        200: openapi.Response(
            description="List of upcoming medications with dose times",
            schema=openapi.Schema(
                type=openapi.TYPE_ARRAY,
                items=upcoming_medication_response
            )
        )
    }
)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_todays_upcoming_medications(request):
    """Return today's medications with upcoming dose times after the current time."""
    user_tz = request.user_timezone
    user_now = timezone.now().astimezone(user_tz)
    
    # Get the start and end of the user's current day
    user_today_start = user_now.replace(hour=0, minute=0, second=0, microsecond=0)
    user_today_end = user_today_start + timedelta(days=1)
    
    # Convert to UTC for database queries
    today_start_utc = user_today_start.astimezone(pytz.UTC)
    today_end_utc = user_today_end.astimezone(pytz.UTC)

    # Get the current time in user's timezone, then convert to UTC for comparison
    user_now = timezone.now().astimezone(user_tz)
    now_utc = user_now.astimezone(pytz.UTC)

    # Filter active medications that could have doses today
    medications = Medication.objects.filter(
        user=request.user,
        first_time_of_intake__lte=today_end_utc  # Started today or before
    ).filter(
        Q(stopped_by_datetime__isnull=True) | Q(stopped_by_datetime__gte=today_start_utc)  # Not stopped or stopped after today started
    )

    upcoming_medications = []

    for med in medications:
        # Get today's scheduled dose times in UTC
        todays_doses_utc = get_todays_scheduled_doses(med, today_start_utc, today_end_utc)
        
        # Filter for upcoming doses only (after current time in user's timezone)
        upcoming_doses_utc = [dose_time for dose_time in todays_doses_utc if dose_time > now_utc]
        
        # Create a response entry for each upcoming dose
        for dose_time_utc in upcoming_doses_utc:
            # Convert dose time to user's timezone for display
            dose_time_user = dose_time_utc.astimezone(user_tz)
            
            medication_entry = {
                'medication_name': med.medication_name,
                'route_of_administration': med.route_of_administration,
                'dosage_form': med.dosage_form,
                'dosage_quantity_of_units_per_time': float(med.dosage_quantity_of_units_per_time),
                'time_for_intake': dose_time_user.strftime('%I:%M %p'),  # 12-hour format
                '_sort_time': dose_time_utc  # For sorting purposes
            }
            upcoming_medications.append(medication_entry)

    # Sort medications by their dose time
    upcoming_medications.sort(key=lambda med: med['_sort_time'])
    
    # Remove the sorting helper field before returning
    for med in upcoming_medications:
        del med['_sort_time']

    return Response(upcoming_medications)