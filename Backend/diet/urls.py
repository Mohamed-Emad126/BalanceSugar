
# urls.py
from django.urls import path,include
from . import views

app_name = 'diet'
urlpatterns = [
    path('food_types/', views.list_food_types, name='list_food_types'),
    path('food/', views.get_food_list, name='food_list'),
    path('create/', views.create_meal, name='create_meal'),
    path('', views.get_meal_list, name='meal_list'),
    path('<int:meal_id>/', views.get_meal, name='meal_detail'),
    # path('<str:food_name>/', views.get_meal, name='meal_by_food_name'),
    path('<int:meal_id>/update/', views.update_meal, name='update_meal'),
    path('<int:meal_id>/delete/', views.delete_meal, name='meal_delete'),
    path('daily_summary/', views.get_daily_summary, name='get_calorie_info'),
    path('step_history/', views.get_step_history, name='get_step_history'),
    path ('nutrition/' , views.calculate_nutrition_by_portion , name='calculate_nutrition_by_portion'),
    path('calorie_summary/', views.calorie_summary, name='calorie-summary'),
    path('nutrition_summary/', views.nutrition_summary, name='nutrition_summary'),
    path('record_cumulative_steps/', views.record_cumulative_steps, name='record_cumulative_steps'),
    path('steps_today/', views.get_today_step_record, name='get_today_step_record'),
    # path('', include('diet.formss.urls')),
]










