from django.db import models
from django.dispatch import receiver
from django.db.models.signals import post_save , post_delete
from django.http import response
from django.utils import timezone
from accounts.models import User , Profile
from decimal import Decimal
import os 
from django.conf import settings
import csv
from datetime import datetime, time
import pytz

class DailySummary(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='daily_summaries')
    date = models.DateField(default=timezone.now)
    total_calories_consumed = models.DecimalField(max_digits=8, decimal_places=0, default=0)
    total_protein = models.DecimalField(max_digits=8, decimal_places=0, default=0)
    total_carbs = models.DecimalField(max_digits=8, decimal_places=0, default=0)
    total_fats = models.DecimalField(max_digits=8, decimal_places=0, default=0)
    total_sugars = models.DecimalField(max_digits=8, decimal_places=0, default=0)
    total_steps = models.IntegerField(default=0)
    calories_burned_by_steps = models.DecimalField(max_digits=8, decimal_places=0, default=0)
    calories_remaining = models.DecimalField(max_digits=8, decimal_places=0, default=0)
    net_calories = models.DecimalField(max_digits=8, decimal_places=0, default=0)

    class Meta:
        unique_together = ('user', 'date')

    def __str__(self):
        return f"{self.user.email} - {self.date}"

    def calculate_daily_totals(self, user_timezone):
        """Recalculate all values using timezone-aware date filtering."""

        # Fallback to UTC if timezone not passed
        if user_timezone is None:
            user_timezone = pytz.UTC
        elif isinstance(user_timezone, str):
            user_timezone = pytz.timezone(user_timezone)

        # Build UTC range for user's local calendar day
        start_local = datetime.combine(self.date, time.min)
        end_local = datetime.combine(self.date, time.max)

        start_aware = timezone.make_aware(start_local, user_timezone)
        end_aware = timezone.make_aware(end_local, user_timezone)

        start_utc = start_aware.astimezone(pytz.UTC)
        end_utc = end_aware.astimezone(pytz.UTC)

        # Meals created within this local day (converted to UTC)
        meals = Meal.objects.filter(
            user=self.user,
            created_at__gte=start_utc,
            created_at__lte=end_utc
        )

        self.total_calories_consumed = sum([meal.calories for meal in meals])
        self.total_protein = sum([meal.protein for meal in meals])
        self.total_carbs = sum([meal.carbohydrates for meal in meals])
        self.total_fats = sum([meal.fat for meal in meals])
        self.total_sugars = sum([meal.sugars for meal in meals])

        # Steps (assumed to be stored with correct date field already)
        steps_today = StepHistory.objects.filter(user=self.user, date=self.date).first()
        if steps_today:
            self.total_steps = steps_today.steps
            self.calories_burned_by_steps = steps_today.calories_burned
        else:
            self.total_steps = 0
            self.calories_burned_by_steps = Decimal('0.0')

        # Goals
        calorie_goal, _ = CalorieGoals.objects.get_or_create(user=self.user, defaults={'daily_calorie_goal': 2000})
        self.calories_remaining = calorie_goal.daily_calorie_goal - self.total_calories_consumed
        self.net_calories = self.total_calories_consumed - self.calories_burned_by_steps

    def save(self, *args, **kwargs):
        """
        Auto-calculate all totals before saving, unless user is being deleted.
        Accepts optional `user_timezone` kwarg.
        """
        user_tz = kwargs.pop('user_timezone', None)

        # ✅ Preserve user deletion safeguard
        if hasattr(self, 'user') and self.user and not self.user.pk:
            super().save(*args, **kwargs)
            return

        # Use passed timezone, fallback to user's profile or UTC
        if not user_tz:
            user_tz = getattr(self.user, 'timezone', 'UTC')

        self.calculate_daily_totals(user_tz)
        super().save(*args, **kwargs)


class CalorieGoals(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="calorie_goals")
    daily_calorie_goal = models.DecimalField(max_digits=7, decimal_places=0, default=Decimal('2000.00'))
    daily_protein_goal = models.DecimalField(max_digits=7, decimal_places=0, null=True, blank=True)
    daily_carb_goal = models.DecimalField(max_digits=7, decimal_places=0, null=True, blank=True)
    daily_fat_goal = models.DecimalField(max_digits=7, decimal_places=0, null=True, blank=True)

    def calculate_bmr(self):
        """Calculate BMR based on user's profile data."""
        profile = getattr(self.user, 'profile', None)
        if not profile:
            return None

        weight = profile.weight
        height = profile.height
        age = profile.age
        gender = profile.gender

        if None in [weight, height, age, gender]:
            return None  # Cannot calculate without full data

        if gender == 'Male':
            bmr = 10 * weight + 6.25 * height - 5 * age + 5
        else:
            bmr = 10 * weight + 6.25 * height - 5 * age - 161

        return Decimal(bmr)

    def calculate_daily_calorie_goal(self):
        """Use BMR × activity factor (default sedentary)."""
        bmr = self.calculate_bmr()
        if bmr is None:
            return None
        activity_factor = Decimal('1.2')  # sedentary
        return bmr * activity_factor

    def calculate_macros(self, daily_calories):
        """Calculate macros distribution."""
        if not daily_calories:
            return None

        calories = float(daily_calories)

        protein_calories = calories * 0.30
        carbs_calories = calories * 0.40
        fats_calories = calories * 0.30

        protein_grams = protein_calories / 4
        carbs_grams = carbs_calories / 4
        fats_grams = fats_calories / 9

        return {
            'protein': round(protein_grams, 1),
            'carbs': round(carbs_grams, 1),
            'fats': round(fats_grams, 1),
        }

    def save(self, *args, **kwargs):
        # Recalculate calorie goal and macros on save
        calculated_goal = self.calculate_daily_calorie_goal()
        if calculated_goal is not None:
            self.daily_calorie_goal = calculated_goal

        macros = self.calculate_macros(self.daily_calorie_goal)
        if macros:
            self.daily_protein_goal = macros['protein']
            self.daily_carb_goal = macros['carbs']
            self.daily_fat_goal = macros['fats']

        super().save(*args, **kwargs)

    def __str__(self):
        return f"Calorie Goals for {self.user.email if self.user else 'Unknown User'}"



# Updated models.py - Add these changes to your existing models

class CumulativeSteps(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, primary_key=True)
    last_cumulative_value = models.IntegerField(default=0)
    last_updated = models.DateField(null=True, blank=True)
    
    # Add this field to track the baseline for current day
    current_day_baseline = models.IntegerField(default=0)
    baseline_date = models.DateField(null=True, blank=True)

    def reset_daily_baseline(self, new_date, last_cumulative):
        """Reset baseline for a new day"""
        self.current_day_baseline = last_cumulative
        self.baseline_date = new_date
        self.last_cumulative_value = last_cumulative
        self.last_updated = new_date
        self.save()

    def __str__(self):
        return f"Cumulative Steps for {self.user.email} - Last: {self.last_cumulative_value}"


# Updated StepHistory model (add index for better performance)
class StepHistory(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    steps = models.IntegerField()
    cumulative_steps = models.IntegerField(default=0)
    calories_burned = models.DecimalField(max_digits=7, decimal_places=2, default=Decimal('0.00'))
    distance = models.DecimalField(max_digits=6, decimal_places=2, default=Decimal('0.00'))
    date = models.DateField()
    created_at = models.DateTimeField(auto_now_add=True)  # Add timestamp for same-day updates

    class Meta:
        unique_together = ('user', 'date')  # Ensure one record per user per day
        indexes = [
            models.Index(fields=['user', 'date']),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.date} - {self.steps} steps"

    def calculate_calories_burned(self):
        # Ensure steps is a proper integer value
        steps_value = getattr(self, 'steps', 0)
        if hasattr(steps_value, '__int__'):
            steps_value = int(steps_value)
        calories_burned = Decimal(str(steps_value)) * Decimal('0.04')
        return calories_burned

    def calculate_distance_km(self):
        step_length_meters = Decimal("0.762")
        # Ensure steps is a proper integer value
        steps_value = getattr(self, 'steps', 0)
        if hasattr(steps_value, '__int__'):
            steps_value = int(steps_value)
        distance_km = (Decimal(str(steps_value)) * step_length_meters) / Decimal(1000)
        return round(distance_km, 2)

    def save(self, *args, **kwargs):
        # Calculate calories and distance before saving
        calculated_calories = self.calculate_calories_burned()
        calculated_distance = self.calculate_distance_km()
        
        # Set the calculated values
        self.calories_burned = calculated_calories
        self.distance = calculated_distance
        
        super().save(*args, **kwargs)



class Food(models.Model):
    name = models.CharField(max_length=255)
    calories = models.DecimalField(max_digits=6, decimal_places=2, default=0)
    fat = models.DecimalField(max_digits=6, decimal_places=2, default=0)
    carbohydrates = models.DecimalField(max_digits=6, decimal_places=2, default=0)
    protein = models.DecimalField(max_digits=6, decimal_places=2, default=0)
    portion_size = models.DecimalField(max_digits=6, decimal_places=2, default=100)
    sugars = models.DecimalField(max_digits=6, decimal_places=2, default=0) 


    def __str__(self):
        return self.name
    

class Meal(models.Model):
    MEAL_TYPE_CHOICES = [
        ("breakfast", "Breakfast"),
        ("lunch", "Lunch"),
        ("dinner", "Dinner"),
        ("snack", "Snack"),
    ]

    meal_id = models.AutoField(primary_key=True)
    meal_type = models.CharField(max_length=10, choices=MEAL_TYPE_CHOICES, default='snack')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='meals')
    food_name = models.ForeignKey(Food, on_delete=models.CASCADE)
    portion_size = models.DecimalField(max_digits=7, decimal_places=2)  # Portion size in grams
    calories = models.DecimalField(max_digits=7, decimal_places=2, default=0.0)
    fat = models.DecimalField(max_digits=7, decimal_places=2, default=0.0)
    carbohydrates = models.DecimalField(max_digits=7, decimal_places=2, default=0.0)
    protein = models.DecimalField(max_digits=7, decimal_places=2, default=0.0)
    sugars = models.DecimalField(max_digits=7, decimal_places=2, default=0.0)
    created_at = models.DateTimeField(auto_now_add=True)
    calories_consumed = models.DecimalField(max_digits=7, decimal_places=2, default=0.0)  # Track total calories consumed
    daily_calorie_goal = models.DecimalField(max_digits=7, decimal_places=2, default=2000.0)  # User's daily calorie goal
    calories_remaining = models.DecimalField(max_digits=7, decimal_places=2, default=2000.0)  # Remaining calories

    def __str__(self):
        return f"{self.food_name} ({self.meal_type})"

    def get_nutrition_data(self, food_name):
        """
        Retrieves the nutrition data for the given food name from the CSV file.
        """
        data_dir = os.path.join(settings.BASE_DIR, 'diet/data')  # Path to your data folder
        csv_file_path = os.path.join(data_dir, 'nutrition.csv')

        # Function to clean the numeric values
        def clean_value(value):
            if value:
                try:
                    # Remove non-numeric characters and return the value as Decimal
                    return Decimal(value.replace(' g', '').replace(' mg', '').replace('ml', '').strip())
                except ValueError:
                    return Decimal('0.0')  # If conversion fails, return 0.0
            return Decimal('0.0')

        try:
            with open(csv_file_path, mode='r', newline='', encoding='utf-8') as csvfile:
                reader = csv.DictReader(csvfile)
                for row in reader:
                    if row['name'].lower() == food_name.lower():
                        return {
                            'calories': clean_value(row['calories']),
                            'fat': clean_value(row['fat']),
                            'carbohydrates': clean_value(row['carbohydrate']),
                            'protein': clean_value(row['protein']),
                            'sugars': clean_value(row['sugars']),
                        }
        except FileNotFoundError:
            return None

        return None

    def calculate_nutrition(self):
        """
        Calculate the nutrition values based on the portion size and food_name entered.
        """
        nutrition_data = self.get_nutrition_data(self.food_name.name)  # Get the nutrition data from the CSV
        if nutrition_data:
            portion_size = Decimal(str(self.portion_size))  # Ensure portion_size is a Decimal
            factor = portion_size / Decimal('100.0') # Portion size ratio over 100g
            self.calories = nutrition_data['calories'] * factor
            self.fat = nutrition_data['fat'] * factor
            self.carbohydrates = nutrition_data['carbohydrates'] * factor
            self.protein = nutrition_data['protein'] * factor
            self.sugars = nutrition_data['sugars'] * factor
             # Ensure both calories are in Decimal type for the += operation
            self.calories_consumed = Decimal(str(self.calories_consumed))  # Cast calories_consumed to Decimal
            self.calories_consumed += self.calories  # Add the calories of this meal to the total consumed  # Add the calories of this meal to the total consumed

    def save(self, *args, **kwargs):
        """Override the save method to calculate nutrition before saving."""
        self.calculate_nutrition()  
        if not self.daily_calorie_goal:
            try:
                goal = CalorieGoals.objects.get(user=self.user)
                self.daily_calorie_goal = goal.daily_calorie_goal
                try:
                    remainings = DailySummary.objects.get(user=self.user, date=self.date)
                    self.calories_remaining = remainings.calories_remaining
                except DailySummary.DoesNotExist:
                    self.calories_remaining = self.daily_calorie_goal
            except CalorieGoals.DoesNotExist:
                self.daily_calorie_goal = 2000
                
        super().save(*args, **kwargs)


@receiver(post_save, sender=Profile)
def create_or_update_calorie_goals(sender, instance, created, **kwargs):
    """
    Automatically create or update Calorie Goals when Profile has enough information.
    """
    user = instance.user

    # Check if weight, height, age, and gender are filled
    if all([instance.weight, instance.height, instance.age, instance.gender]):
        # Create or update Calorie Goals
        calorie_goals, created = CalorieGoals.objects.get_or_create(user=user)
        calorie_goals.save()  # This will auto-recalculate using your save() method



@receiver(post_save , sender = Meal)
def update_daily_summary_on_meal_save(sender, instance, **kwargs):
    # Calculate the date in user's timezone based on created_at
    # For now, we'll use UTC as default since we don't have access to user timezone in signals
    # The actual timezone-aware calculation will happen when the summary is accessed
    meal_date = instance.created_at.date()
    recalculate_daily_summary(instance.user, meal_date)

@receiver(post_delete, sender=Meal)
def update_daily_summary_on_meal_delete(sender, instance, **kwargs):
    # Calculate the date in user's timezone based on created_at
    meal_date = instance.created_at.date()
    recalculate_daily_summary(instance.user, meal_date)


def recalculate_daily_summary(user, date, user_timezone=None):
    try:
        if not user or not user.pk:
            return
        summary, _ = DailySummary.objects.get_or_create(user=user, date=date)
        summary.save(user_timezone=user_timezone)
    except Exception:
        pass


@receiver(post_save, sender=StepHistory)
def update_daily_summary_on_step_save(sender, instance, **kwargs):
    """Update daily summary when step history is saved."""
    # Skip if this is a deletion operation
    if kwargs.get('created') is False and not instance.pk:
        return
    # Check if user still exists before proceeding
    if hasattr(instance, 'user') and instance.user and instance.user.pk:
        recalculate_daily_summary(instance.user, instance.date)


@receiver(post_delete, sender=StepHistory)
def update_daily_summary_on_step_delete(sender, instance, **kwargs):
    """Update daily summary when step history is deleted."""
    # Skip recalculation during deletion to avoid foreign key issues
    return


@receiver(post_save, sender=CumulativeSteps)
def update_daily_summary_on_cumulative_steps_save(sender, instance, **kwargs):
    """Update daily summary when cumulative steps are saved."""
    # Skip if this is a deletion operation
    if kwargs.get('created') is False and not instance.pk:
        return
    # Check if user still exists and has last_updated before proceeding
    if (hasattr(instance, 'user') and instance.user and instance.user.pk and 
        instance.last_updated):
        recalculate_daily_summary(instance.user, instance.last_updated)