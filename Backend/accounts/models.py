from django.db import models
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.dispatch import receiver
from django.utils.translation import gettext_lazy as _
from .managers import UserManager
from rest_framework_simplejwt.tokens import RefreshToken
from django.db.models.signals import post_save
from django.conf import settings
from django.contrib.auth import get_user_model
from decimal import Decimal
import os
# Create your models here.



AUTH_PROVIDERS = {'email' : 'email' , 'google' : 'google' , 'facebook': 'facebook'}
class User(AbstractBaseUser,PermissionsMixin):
    email = models.EmailField(max_length=255, unique=True , verbose_name=_('Email address'))
    first_name = models.CharField(max_length=100 , verbose_name=_('First Name'))
    last_name = models.CharField(max_length=100 , verbose_name=_('Last Name'))
    is_staff = models.BooleanField(default=False)
    is_superuser = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    date_joined = models.DateTimeField(auto_now_add=True)
    last_login= models.DateTimeField(auto_now=True)
    auth_provider = models.CharField(max_length=50 , default=AUTH_PROVIDERS.get('email'))

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ["first_name" , "last_name"]

    objects = UserManager()

    def __str__(self):
        return self.email
    
    @property
    def get_full_name(self):
        return f"{self.first_name} {self.last_name}"
    
    def tokens(self):
        refresh = RefreshToken.for_user(self)
        return {
            'refresh': str(refresh),
            'access': str(refresh.access_token)
        }
    
User = get_user_model()
class OneTimePassword(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    code = models.CharField(max_length=6)

    def __str__(self):
        return f"{self.user.first_name}-passcode"
    




SUGAR_TYPE_CHOICES = (
    ('Type 1', 'Type 1'),
    ('Type 2', 'Type 2'),
    ('Pre Diabetic', 'Pre Diabetic'),
    ('Genetic Predisposition', 'Genetic Predisposition'),
    ('Normal', 'Normal'),
)

GENDER_CHOICES = (('Male', 'Male'), ('Female', 'Female'))
THERAPY_CHOICES = (('Insulin', 'Insulin'), ('Tablets', 'Tablets'))

def profile_image_path(instance, filename):
    """Generate upload path for profile images"""
    # Get file extension
    ext = filename.split('.')[-1]
    # Create filename using user id
    filename = f'profile_{instance.user.id}.{ext}'
    return os.path.join('profile/', filename)

class Profile(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name="profile"
    )
    image = models.ImageField(
        upload_to=profile_image_path, 
        default='default.jpeg', 
        blank=True, 
        null=True
    )
    gender = models.CharField(max_length=10, choices=GENDER_CHOICES, blank=True, null=True)
    therapy = models.CharField(max_length=10, choices=THERAPY_CHOICES, blank=True, null=True)
    weight = models.FloatField(null=True, blank=True)
    height = models.FloatField(null=True, blank=True)
    diabetes_type = models.CharField(max_length=22, choices=SUGAR_TYPE_CHOICES, blank=True, null=True)
    age = models.PositiveIntegerField(null=True, blank=True)

    def __str__(self):
        return self.user.email if self.user else "Unknown User"
    
    def delete(self, *args, **kwargs):
        if self.image and self.image.name != 'default.jpeg':
            try:
                self.image.delete(save=False)
            except:
                pass
        super().delete(*args, **kwargs)


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)

@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def save_user_profile(sender, instance, **kwargs):
    if hasattr(instance, 'profile'):
        instance.profile.save()
    else:
        Profile.objects.create(user=instance)



class PasswordResetOTP(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    code = models.CharField(max_length=6)

    def __str__(self):
        return f"{self.user.first_name}-passcode"