# glucose/urls.py

from django.urls import path
from .views import Last16MeasurementsAPIView, AllMeasurementsAPIView, AddMeasurementAPIView
app_name = 'diabetis'
urlpatterns = [
    path('history/last16/', Last16MeasurementsAPIView.as_view(), name='last-16-measurements'),
    path('history/all/', AllMeasurementsAPIView.as_view(), name='all-measurements'),
    path('add/', AddMeasurementAPIView.as_view(), name='add-measurement'),
]
