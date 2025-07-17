

from django.urls import path
from . import views

app_name = 'medication'

urlpatterns = [
    path('', views.get_medications, name='list_medications'),
    path('<int:primary_key>/', views.get_medication, name='get_medication'),
    path('create/', views.create_medication, name='create_medication'),
    path('update/<int:primary_key>/', views.update_medication, name='update_medication'),
    path('delete/<int:primary_key>/', views.delete_medication, name='delete_medication'),
    path('active_medications/', views.get_active_medications, name='get_active_medications'),
    path('today_upcoming/', views.get_todays_upcoming_medications, name='get_todays_upcoming_medications'),
    path('medication_day/', views.get_medications_on_day, name='get_medications_on_day'),

]


