from django.contrib import admin
from .models import User , Profile , OneTimePassword ,PasswordResetOTP
# Register your models here.

admin.site.register(User)
admin.site.register(OneTimePassword)
admin.site.register(Profile)
admin.site.register(PasswordResetOTP)