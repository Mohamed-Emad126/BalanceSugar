# views.py
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.db.models import Q, Sum
from django.utils import timezone
from decimal import Decimal
from drf_yasg.utils import swagger_auto_schema
from .models import Food, Meal , StepHistory, DailySummary , CalorieGoals , CumulativeSteps
from .serializers import FoodSerializer, MealSerializer , StepHistorySerializer, DailySummarySerializer
from datetime import date, timedelta
from drf_yasg import openapi
import pytz
from django.utils.timezone import localtime


# 1- Retrieve a list of all available meal types
@swagger_auto_schema(method='get', responses={200: 'List of available meal types'})
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_food_types(request):
    """Retrieve a list of all available meal types."""
    
    meal_types = ['breakfast', 'lunch', 'dinner', 'snack']
    return Response({"meal_types": meal_types}, status=status.HTTP_200_OK)


# 2- Retrieve a list of all available foods, with optional search query
@swagger_auto_schema(method='get', responses={200: FoodSerializer(many=True)})
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_food_list(request):
    """Retrieve a list of all available foods, with an optional search query."""
    
    search_query = request.GET.get('search', '').strip()  
    
    if search_query:
        foods = Food.objects.filter(Q(name__icontains=search_query))
    else:
        foods = Food.objects.all()

    serializer = FoodSerializer(foods, many=True)
    return Response({"foods": serializer.data}, status=status.HTTP_200_OK)


# 3- Create a new meal
@swagger_auto_schema(method='post', request_body=MealSerializer, responses={201: MealSerializer})
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_meal(request):
    """Create a new meal by selecting a food and specifying a portion size."""
    
    data = request.data  
    
    if 'food_name' not in data:
        return Response({'error': 'Food name is required.'}, status=status.HTTP_400_BAD_REQUEST)

    food_name = data['food_name'].strip()

    try:
        food = Food.objects.get(name__iexact=food_name)
    except Food.DoesNotExist:
        return Response({'error': 'Food not found.'}, status=status.HTTP_400_BAD_REQUEST)

    portion_size = data.get('portion_size', 100)
    meal_type = data.get('meal_type', 'snack').strip()

    if meal_type not in ['breakfast', 'lunch', 'dinner', 'snack']:
        return Response({'error': 'Invalid meal type. Choose one of: breakfast, lunch, dinner, snack.'}, status=status.HTTP_400_BAD_REQUEST)

    meal = Meal.objects.create(
        user=request.user,
        food_name=food,
        meal_type=meal_type,
        portion_size=portion_size,
    )

    meal.calculate_nutrition()
    meal.save()

    serializer = MealSerializer(meal)
    return Response(serializer.data, status=status.HTTP_201_CREATED)


# 4- Retrieve all meals for the authenticated user, grouped by meal type
@swagger_auto_schema(method='get', responses={200: "Meals grouped by meal type"})
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_meal_list(request):
    """Retrieve all meals for the authenticated user, grouped by meal type for today."""

    user_tz = request.headers.get("User-Timezone", "UTC")
    user_timezone = pytz.timezone(user_tz)

    # Get user’s today date in their local timezone
    user_now = timezone.now().astimezone(user_timezone)
    user_today = user_now.date()

    # Retrieve objects and filter by local date
    meals = Meal.objects.filter(user=request.user)
    meals = [
        meal for meal in meals
        if localtime(meal.created_at, user_timezone).date() == user_today
        ]
    meal_groups = {
        "breakfast": [],
        "lunch": [],
        "dinner": [],
        "snack": []
    }

    for meal in meals:
        meal_data = {
            "id": meal.meal_id,
            "food_name": meal.food_name.name,
            "portion_size": meal.portion_size,
            "calories": meal.calories,
            "protein":meal.protein,
            "carbohydrates":meal.carbohydrates,
            "fat":meal.fat,
            "sugars":meal.sugars,
        }
        meal_groups[meal.meal_type].append(meal_data)

    return Response(meal_groups, status=status.HTTP_200_OK)


# 5- Retrieve the details of a single meal by meal_id or food name
@swagger_auto_schema(method='get', responses={200: MealSerializer})
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_meal(request, meal_id ):
    try:
        meal = Meal.objects.get(meal_id=meal_id, user=request.user)
    except Meal.DoesNotExist:
        return Response({"error": "Meal not found."}, status=status.HTTP_404_NOT_FOUND)
    serializer = MealSerializer(meal, many=False)
    return Response(serializer.data, status=status.HTTP_200_OK)


# # 6- Retrieve the list of foods consumed grouped by day.  
# @swagger_auto_schema(method='get', responses={200: MealSerializer(many=True)})
# @api_view(['GET'])
# @permission_classes([IsAuthenticated])
# def list_foods_by_day(request):
#     """Retrieve the list of foods consumed by the authenticated user, grouped by day."""
    
#     # Get the 'date' query parameter, if provided
#     date_str = request.GET.get('date', None)
#     if date_str:
#         try:
#             # Parse the date string to a datetime object
#             date = timezone.datetime.strptime(date_str, "%Y-%m-%d").date()
#         except ValueError:
#             return Response({"error": "Invalid date format. Use YYYY-MM-DD."}, status=status.HTTP_400_BAD_REQUEST)
#     else:
#         # If no date is provided, default to today's date
#         date = timezone.now().date()
    
#     # Fetch meals for the specific date
#     meals = Meal.objects.filter(user=request.user, created_at__date=date)
    
#     # Group meals by meal type
#     meal_groups = {
#         "breakfast": [],
#         "lunch": [],
#         "dinner": [],
#         "snack": []
#     }

#     for meal in meals:
#         meal_data = {
#             "id": meal.meal_id,
#             "food_name": meal.food_name.name,
#             "portion_size": meal.portion_size,
#             "calories": meal.calories,
#             "protein": meal.protein,
#             "carbohydrates": meal.carbohydrates,
#             "fat": meal.fat,
#             "sugars": meal.sugars,
#         }
#         meal_groups[meal.meal_type].append(meal_data)

#     return Response(meal_groups, status=status.HTTP_200_OK)

# 7- Update an existing meal
@swagger_auto_schema(method='put', request_body=MealSerializer, responses={200: MealSerializer})
@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_meal(request, meal_id):
    """Update an existing meal."""
    
    data = request.data
    food_name = data.get('food_name', '').strip()

    try:
        food_instance = Food.objects.get(name__iexact=food_name)
    except Food.DoesNotExist:
        return Response({"error": "Food not found."}, status=status.HTTP_404_NOT_FOUND)

    try:
        meal = Meal.objects.get(meal_id=meal_id, user=request.user)
    except Meal.DoesNotExist:
        return Response({"error": "Meal not found."}, status=status.HTTP_404_NOT_FOUND)

    meal.food_name = food_instance
    meal.portion_size = data.get('portion_size', meal.portion_size)
    meal.meal_type = data.get('meal_type', meal.meal_type)
    
    meal.calculate_nutrition()
    meal.save()
    
    serializer = MealSerializer(meal)
    return Response(serializer.data, status=status.HTTP_200_OK)


# 8- Delete an existing meal
@swagger_auto_schema(method='delete', responses={204: 'No Content'})
@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_meal(request, meal_id):
    """Delete an existing meal."""
    
    try:
        meal = Meal.objects.get(meal_id=meal_id, user=request.user)
        meal.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    except Meal.DoesNotExist:
        return Response({"error": "Meal not found."}, status=status.HTTP_404_NOT_FOUND)


#10.an API to view your step history and calories burned:
@swagger_auto_schema(method='get', responses={200: StepHistorySerializer(many=True)})
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_step_history(request):
    """Retrieve the history of steps and calories burned by the user."""
    
    # Fetch step history for the authenticated user
    step_history = StepHistory.objects.filter(user=request.user).order_by('-date')

    serializer = StepHistorySerializer(step_history, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)
    

@swagger_auto_schema(
    method='post',
    request_body=openapi.Schema(
        type=openapi.TYPE_OBJECT,
        properties={
            'cumulative_steps': openapi.Schema(
                type=openapi.TYPE_INTEGER,
                description='Total steps since device boot'
            ),
        },
        required=['cumulative_steps']
    ),
    responses={
        201: StepHistorySerializer,
        400: 'Bad Request - Invalid data',
        500: 'Internal Server Error'
    }
)
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def record_cumulative_steps(request):
    """
    Record cumulative steps from pedometer and calculate daily steps.
    
    Algorithm:
    - First reading of the day: becomes baseline
    - Subsequent readings: daily_steps = cumulative_steps - baseline_for_today
    - Next day: baseline = last_cumulative_value from previous day
    """
    user = request.user
    user_today = timezone.now().astimezone(request.user_timezone).date()
    data = request.data
    
    # Validate input
    cumulative_steps = data.get('cumulative_steps')
    if cumulative_steps is None:
        return Response({'error': 'cumulative_steps is required'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        cumulative_steps = int(cumulative_steps)
        if cumulative_steps < 0:
            raise ValueError("Steps cannot be negative")
    except (ValueError, TypeError) as e:
        return Response({'error': f'cumulative_steps must be a positive integer: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        # Get or create cumulative steps record
        cum_record, created = CumulativeSteps.objects.get_or_create(
            user=user,
            defaults={
                'last_cumulative_value': cumulative_steps,
                'current_day_baseline': cumulative_steps,
                'baseline_date': user_today
            }
        )
        
        daily_steps = 0
        
        if created:
            # First time user - this is the baseline
            daily_steps = 0
            cum_record.current_day_baseline = cumulative_steps
            cum_record.baseline_date = user_today
        else:
            # Check if this is a new day
            if cum_record.baseline_date != user_today:
                # New day - reset baseline to yesterday's last cumulative value
                cum_record.reset_daily_baseline(user_today, cum_record.last_cumulative_value)
                daily_steps = cumulative_steps - cum_record.current_day_baseline
            else:
                # Same day - calculate steps from today's baseline
                daily_steps = cumulative_steps - cum_record.current_day_baseline
        
        # Handle device reset (if cumulative steps went down)
        if daily_steps < 0:
            # Device was reset, treat current reading as new baseline
            cum_record.current_day_baseline = cumulative_steps
            cum_record.baseline_date = user_today
            daily_steps = 0
        
        # Update cumulative record
        cum_record.last_cumulative_value = cumulative_steps
        cum_record.last_updated = user_today
        cum_record.save()
        
        # Create or update daily step history
        step_history, created = StepHistory.objects.update_or_create(
            user=user,
            date=user_today,
            defaults={
                'steps': daily_steps,
                'cumulative_steps': cumulative_steps
            }
        )
        
        # Explicitly save to ensure calories_burned is calculated
        step_history.save()
        
        # Daily summary will be automatically updated by the StepHistory signal
        
        serializer = StepHistorySerializer(step_history)
        
        return Response({
            'step_history': serializer.data,
            'daily_steps_calculated': daily_steps,
            'baseline_for_today': cum_record.current_day_baseline,
            'is_new_day': cum_record.baseline_date == user_today and not created 
        }, status=status.HTTP_201_CREATED )
        
    except Exception as e:
        return Response({
            'error': f'An error occurred while processing steps: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# Update your existing get_today_step_record view to include more info
@swagger_auto_schema(
    method='get',
    responses={
        200: StepHistorySerializer,
        404: 'Not Found'
    }
)
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_today_step_record(request): 
    """Get the current day's step record with additional context."""
    user = request.user
    user_today = timezone.now().astimezone(request.user_timezone).date()

    try:
        step_history = StepHistory.objects.get(user=user, date=user_today)
        serializer = StepHistorySerializer(step_history)
        
        # Add baseline info for context
        try:
            cum_record = CumulativeSteps.objects.get(user=user)
            baseline_info = {
                'baseline_for_today': cum_record.current_day_baseline,
                'baseline_date': cum_record.baseline_date
            }
        except CumulativeSteps.DoesNotExist:
            baseline_info = {}
        
        return Response({
            **serializer.data,
            **baseline_info
        }, status=status.HTTP_200_OK)
        
    except StepHistory.DoesNotExist:
        return Response({
            'message': 'No step record found for today.',
            'date': user_today
        }, status=status.HTTP_404_NOT_FOUND)


    


# 11- Retrieve calorie info (total consumed and remaining for the day)
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_daily_summary(request):
    user = request.user
    user_tz = request.user_timezone
    user_today = timezone.now().astimezone(user_tz).date()

    summary, created = DailySummary.objects.get_or_create(user=user, date=user_today)
    summary.save(user_timezone=user_tz)  # ✅ pass timezone only here
    serializer = DailySummarySerializer(summary)
    return Response(serializer.data, status=status.HTTP_200_OK)




@api_view(['GET'])
@permission_classes([IsAuthenticated])
def nutrition_summary(request):
    """Get today's complete nutrition summary including all macros and their goals."""
    user = request.user
    user_tz = request.user_timezone
    user_today = timezone.now().astimezone(user_tz).date()

    # Get or create daily summary
    daily_summary, created = DailySummary.objects.get_or_create(user=user, date=user_today)
    daily_summary.save(user_timezone=user_tz)
    
    # Get calorie goals
    try:
        calorie_goals = CalorieGoals.objects.get(user=user)
    except CalorieGoals.DoesNotExist:
        # Create default goals if they don't exist
        calorie_goals = CalorieGoals.objects.create(user=user)
        calorie_goals.save()  # This will calculate goals based on profile

    # Calculate remaining values
    calories_remaining = max(0, calorie_goals.daily_calorie_goal - daily_summary.total_calories_consumed)
    protein_remaining = max(0, (calorie_goals.daily_protein_goal or 0) - daily_summary.total_protein)
    carbs_remaining = max(0, (calorie_goals.daily_carb_goal or 0) - daily_summary.total_carbs)
    fats_remaining = max(0, (calorie_goals.daily_fat_goal or 0) - daily_summary.total_fats)

    response_data = {
        'date': str(user_today),
        'calories': {
            'consumed': float(daily_summary.total_calories_consumed),
            'goal': float(calorie_goals.daily_calorie_goal),
            'remaining': float(calories_remaining),
        },
        'protein': {
            'consumed': float(daily_summary.total_protein),
            'goal': float(calorie_goals.daily_protein_goal or 0),
            'remaining': float(protein_remaining),
        },
        'carbs': {
            'consumed': float(daily_summary.total_carbs),
            'goal': float(calorie_goals.daily_carb_goal or 0),
            'remaining': float(carbs_remaining),
        },
        'fats': {
            'consumed': float(daily_summary.total_fats),
            'goal': float(calorie_goals.daily_fat_goal or 0),
            'remaining': float(fats_remaining),
        },
    }

    return Response(response_data, status=status.HTTP_200_OK)
@swagger_auto_schema(
    method='post',
    request_body=openapi.Schema(
        type=openapi.TYPE_OBJECT,
        required=['food_name', 'portion_size'],
        properties={
            'food_name': openapi.Schema(type=openapi.TYPE_STRING),
            'portion_size': openapi.Schema(type=openapi.TYPE_NUMBER),
        },
    ),
    responses={200: 'Calculated nutritional info based on portion size'}
)
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def calculate_nutrition_by_portion(request):
    """Calculate nutritional values based on portion size without creating a meal."""
    data = request.data
    food_name = data.get('food_name', '').strip()
    portion_size = data.get('portion_size', 100)

    if not food_name:
        return Response({'error': 'Food name is required.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        food = Food.objects.get(name__iexact=food_name)
    except Food.DoesNotExist:
        return Response({'error': 'Food not found.'}, status=status.HTTP_404_NOT_FOUND)

    try:
        portion_size = float(portion_size)
        if portion_size <= 0:
            raise ValueError
    except ValueError:
        return Response({'error': 'Invalid portion size.'}, status=status.HTTP_400_BAD_REQUEST)

    factor = Decimal(portion_size) / Decimal(100)  # Scale from per-100g
    calculated_values = {
        'calories': round(food.calories * factor, 0),
        'protein': round(food.protein * factor, 0),
        'carbohydrates': round(food.carbohydrates * factor, 0),
        'fat': round(food.fat * factor, 0),
        'sugars': round(food.sugars * factor, 2),
    }

    return Response(calculated_values, status=status.HTTP_200_OK)





@api_view(['GET'])
@permission_classes([IsAuthenticated])
def calorie_summary(request):
    user = request.user
    user_tz = request.user_timezone
    user_today = timezone.now().astimezone(user_tz).date()

    daily_summary , created = DailySummary.objects.get_or_create(user=user, date=user_today)
    # Recalculate with user timezone to ensure correct meal filtering
    daily_summary.save(user_timezone=user_tz)

    try:
        calorie_goal = CalorieGoals.objects.get(user=user)
    except CalorieGoals.DoesNotExist:
        return Response({"detail": "Calorie goal not set."}, status=status.HTTP_204_NO_CONTENT)

    total_consumed = daily_summary.total_calories_consumed
    burned = daily_summary.calories_burned_by_steps
    daily_goal = calorie_goal.daily_calorie_goal
    available = daily_goal - total_consumed + burned

    return Response({
        "date": str(user_today),
        "calories_burned_by_steps": float(burned),
        "total_calories_consumed": float(total_consumed),
        "daily_calorie_goal": float(daily_goal),
        "available_calories": float(available)
    })



# @swagger_auto_schema(method='get', responses={200: 'Total calories consumed, burned, and remaining for the day.'})
# @api_view(['GET'])
# @permission_classes([IsAuthenticated])
# def get_calorie_info(request):
#     """Retrieve the total calories consumed, burned, and remaining calories for the day."""
    
#     # Get total calories consumed from meals
#     total_calories_consumed = Meal.objects.filter(
#         user=request.user, 
#         date=timezone.now().date()
#     ).aggregate(total_calories=Sum('calories'))['total_calories'] or Decimal('0.0')

#     # Get total steps taken today
#     total_steps = StepHistory.objects.filter(
#         user=request.user, 
#         date=timezone.now().date()
#     ).aggregate(total_steps=Sum('steps'))['total_steps'] or 0
    
#     # Calculate calories burned based on steps (0.04 calories per step as an example)
#     calories_burned_from_steps = total_steps * 0.04  # Assuming 0.04 calories burned per step
#     calories_burned_from_steps = Decimal(calories_burned_from_steps)
    
#     # Get user's daily calorie goal from profile
#     user_profile = request.user.profile
#     daily_calorie_goal = user_profile.daily_calorie_goal  # Automatically calculated in profile
    
#     # Calculate remaining calories: goal - consumed + burned calories
#     remaining_calories = daily_calorie_goal - total_calories_consumed + calories_burned_from_steps

#     # Prepare the response with all relevant calorie information
#     return Response({
#         'calorie_goal': str(daily_calorie_goal),  # Daily calorie goal
#         'total_calories_consumed': str(total_calories_consumed),  # Total calories consumed today
#         'calories_burned_from_steps': str(calories_burned_from_steps),  # Calories burned from steps
#         'remaining_calories': str(remaining_calories),  # Remaining calories for the day
#     }, status=status.HTTP_200_OK)