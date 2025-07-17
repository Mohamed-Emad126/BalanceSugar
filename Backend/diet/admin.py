from django.contrib import admin

# Register your models here.
from .models import Meal , Food, DailySummary , StepHistory , CalorieGoals,CumulativeSteps

admin.site.register(Meal)
admin.site.register(Food)
admin.site.register(DailySummary)
admin.site.register(StepHistory)
admin.site.register(CalorieGoals)
admin.site.register(CumulativeSteps)