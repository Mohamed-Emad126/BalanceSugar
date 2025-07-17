# glucose/views.py

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from .models import BloodGlucose
from .serializers import BloodGlucoseSerializer
from .utils import classify_glucose
import numpy as np
import joblib
from tensorflow.keras.models import load_model
from django.utils.dateparse import parse_datetime
from django.utils import timezone

MODEL_PATH = r"C:\Users\moham\OneDrive\Desktop\Git Uploads\Balance-sugar\Backend\diabetis\resourses\gru_model.keras"
SCALER_PATH = r"C:\Users\moham\OneDrive\Desktop\Git Uploads\Balance-sugar\Backend\diabetis\resourses\scaler.pkl"

# glucose/views.py (imports remain unchanged)

class Last16MeasurementsAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user_tz = request.user_timezone
        measurements = BloodGlucose.objects.filter(user=request.user).order_by('-created_at')[:16][::-1]
        serializer = BloodGlucoseSerializer(measurements, many=True, context={'user_timezone': user_tz})
        return Response(serializer.data)


class AllMeasurementsAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user_tz = request.user_timezone
        measurements = BloodGlucose.objects.filter(user=request.user).order_by('-created_at')
        serializer = BloodGlucoseSerializer(measurements, many=True, context={'user_timezone': user_tz})
        return Response(serializer.data)



class AddMeasurementAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        blood_glucose = request.data.get('blood_glucose')
        time_of_measurement = request.data.get('time_of_measurement', 'Random')
        created_at = request.data.get('created_at') 

        if not blood_glucose:
            return Response({"error": "blood_glucose is required."}, status=400)

        try:
            blood_glucose = float(blood_glucose)
        except ValueError:
            return Response({"error": "blood_glucose must be a float."}, status=400)

        # Classify severity
        severity = classify_glucose(blood_glucose, time_of_measurement)

        # Prediction logic
        user = request.user
        previous_measurements = BloodGlucose.objects.filter(user=user).order_by('-created_at')[:16][::-1]

        if len(previous_measurements) < 16:
            predicted_glucose = 0.0
        else:
            # Scale the last 16 values and predict
            scaler = joblib.load(SCALER_PATH)
            model = load_model(MODEL_PATH, compile=False)
            values = np.array([m.blood_glucose for m in previous_measurements]).reshape(-1, 1)
            scaled = scaler.transform(values).reshape(1, 16, 1)
            prediction = model.predict(scaled)[0][0]
            predicted_glucose = float(scaler.inverse_transform([[prediction]])[0][0])

        # Handle datetime override
        if created_at:
            try:
                created_at = parse_datetime(created_at)
                if created_at is None:
                    raise ValueError
            except:
                return Response({"error": "Invalid datetime format."}, status=400)
        else:
            created_at = timezone.now()

        # Save to DB
        BloodGlucose.objects.create(
            user=user,
            blood_glucose=blood_glucose,
            time_of_measurement=time_of_measurement,
            severity=severity,
            predicted_glucose=predicted_glucose,
            created_at=created_at
        )

        return Response({"message": "Measurement added successfully."}, status=status.HTTP_201_CREATED)
