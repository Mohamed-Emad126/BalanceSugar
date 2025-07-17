# diet/serializers.py

from rest_framework import serializers
from .models import Food, Meal , StepHistory , DailySummary , CalorieGoals


class StepHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = StepHistory
        fields = ['user', 'steps', 'cumulative_steps', 'calories_burned', 'distance', 'date']
        read_only_fields = ['calories_burned', 'distance', 'date', 'user']

class FoodSerializer(serializers.ModelSerializer):
    class Meta:
        model = Food
        fields = ['name','portion_size','calories']

class MealSerializer(serializers.ModelSerializer):
    # Use SerializerMethodField to fetch the food name
    food_name = serializers.CharField(source='food_name.name')  # Get the food name
    

    class Meta:
        model = Meal
        fields = ['meal_id', 'meal_type', 'food_name', 'portion_size', 'calories', 'fat', 'carbohydrates', 'protein', 'sugars', 'created_at']



class DailySummarySerializer(serializers.ModelSerializer):
    # These fields will be calculated from the related CalorieGoals
    daily_calorie_goal = serializers.SerializerMethodField()
    protein_goal = serializers.SerializerMethodField()
    carbs_goal = serializers.SerializerMethodField()
    fats_goal = serializers.SerializerMethodField()

    class Meta:
        model = DailySummary
        fields = [
            'id', 'user', 'date',
            'total_calories_consumed', 
            'total_protein', 
            'total_carbs', 
            'total_fats', 
            'total_sugars',
            'total_steps', 
            'calories_burned_by_steps',
            'calories_remaining', 
            'net_calories',
            'daily_calorie_goal',
            'protein_goal', 
            'carbs_goal', 
            'fats_goal'
        ]
        read_only_fields = fields

    def get_daily_calorie_goal(self, obj):
        return self._get_goal_value(obj, 'daily_calorie_goal')

    def get_protein_goal(self, obj):
        return self._get_goal_value(obj, 'daily_protein_goal')

    def get_carbs_goal(self, obj):
        return self._get_goal_value(obj, 'daily_carb_goal')

    def get_fats_goal(self, obj):
        return self._get_goal_value(obj, 'daily_fat_goal')

    def _get_goal_value(self, obj, field_name):
        try:
            calorie_goals = obj.user.calorie_goals
            return getattr(calorie_goals, field_name)
        except (CalorieGoals.DoesNotExist, AttributeError):
            return None