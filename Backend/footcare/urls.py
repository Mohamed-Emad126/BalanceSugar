

from django.urls import path
from . import views
app_name = 'footcare'
urlpatterns = [
    path('ulcers/', views.get_all_foot_ulcers, name='get_all_foot_ulcers'),
    path('ulcers/<int:ulcer_id>/', views.get_foot_ulcer, name='get_foot_ulcer'),
    path('ulcers/create/', views.create_foot_ulcer, name='create-foot-ulcer'),
    path('ulcers/latest_by_region/', views.get_latest_ulcers_per_region, name='get_latest_ulcers_per_region'),
    path('ulcers/ulcers_by_region/', views.get_ulcers_by_region, name='get_ulcers_by_region'),
    path('ulcers/delete_ulcers_by_region/' , views.delete_ulcers_by_region , name='delete_ulcers_by_region'),
    path('ulcers/<int:ulcer_id>/update/', views.update_foot_ulcer, name='update_foot_ulcer'),
    path('ulcers/<int:ulcer_id>/delete/', views.delete_foot_ulcer, name='delete_foot_ulcer'),
]
