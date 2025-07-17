from rest_framework import serializers
from .models import User , Profile , PasswordResetOTP
from django.contrib.auth import authenticate
from rest_framework.exceptions import AuthenticationFailed
from django.contrib.auth.tokens import PasswordResetTokenGenerator
from django.utils.http import urlsafe_base64_encode , urlsafe_base64_decode
from django.contrib.sites.shortcuts import get_current_site
from django.urls import reverse
from .utlis import send_password_reset_code_to_user
from rest_framework_simplejwt.tokens import RefreshToken
from .models import OneTimePassword
from django.contrib.auth import get_user_model

class UserRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(max_length=68, min_length=6, write_only=True)
    password2 = serializers.CharField(max_length=68, min_length=6, write_only=True)

    class Meta:
        model = User
        fields = ['email', 'first_name', 'last_name', 'password', 'password2']


        def validate(self, attrs):
            password = attrs.get('password' ,'')
            password2 = attrs.get('password2' ,'')
            if password != password2:
                raise serializers.ValidationError({"password": "Password fields didn't match!"})
            
            return attrs
        
    def create(self, validated_data):
        validated_data.pop('password2')  # Remove password2 before creating the user
        user = User.objects.create_user(**validated_data)  # Hashes password automatically
        return user
    

class VerifyOTPSerializer(serializers.Serializer):
    otp = serializers.CharField(max_length=6, required=True)



class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=255)
    password = serializers.CharField(max_length=68, min_length=6 , write_only=True)
    full_name = serializers.CharField(max_length=255, read_only=True)
    access_token = serializers.CharField(max_length=255, read_only=True)
    refreash_token = serializers.CharField(max_length=255, read_only=True)

    class Meta:
        model= User
        fields = ['email', 'password', 'full_name', 'access_token', 'refreash_token']

    def validate(self, attrs):
        email = attrs.get('email', '')
        password = attrs.get('password','')
        request = self.context.get('request')
        user = authenticate(request, email=email, password=password)
        if not user:
            raise AuthenticationFailed('Invalid credentials, try again')
        if not user.is_verified:
            raise AuthenticationFailed('Account is not verified')
        
        user_tokens = user.tokens()

        return {
            'email': user.email,
            'full_name': user.get_full_name,
            'access_token':str(user_tokens.get('access')),
            'refreash_token': str(user_tokens.get('refresh'))
        }

class SendResetOTPSerializer(serializers.Serializer):
    email = serializers.EmailField()

    def validate_email(self, email):
        if not User.objects.filter(email=email).exists():
            raise serializers.ValidationError("User with this email does not exist.")
        return email

class ConfirmResetOTPSerializer(serializers.Serializer):
    otp = serializers.CharField(max_length=6)

class ResetPasswordSerializer(serializers.Serializer):
    new_password = serializers.CharField(min_length=6, write_only=True)

    def validate_new_password(self, value):
        if len(value) < 6:
            raise serializers.ValidationError("Password must be at least 6 characters long.")
        return value

        

        
class LogoutUserSerializer(serializers.Serializer):
    refresh = serializers.CharField()
    default_error_message= {
        'bad_token': ('Token is invalid or expired')
        }

    def validate(self, attrs):
        self.token= attrs.get('refresh_token')

        return attrs
            
    def save(self, **kwargs):
        try: 
            token = RefreshToken(self.token)
            token.blacklist()
        except:
            return self.fail('bad_token')
        


class ProfileSerializer(serializers.ModelSerializer):
    user = serializers.PrimaryKeyRelatedField(read_only=True)
    image_url = serializers.SerializerMethodField()  # Add this field to get full URL
    
    class Meta:
        model = Profile
        fields = ['user', 'image', 'image_url', 'gender', 'therapy', 'weight', 'height', 'diabetes_type', 'age']
        extra_kwargs = {
            'image': {'required': False}  # Make image field optional for updates
        }

    def get_image_url(self, obj):
        """Return the full URL for the image"""
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None

    def validate_weight(self, value):
        """Ensure weight is within a reasonable range"""
        if value is not None and (value < 20 or value > 300):
            raise serializers.ValidationError("Weight must be between 20kg and 300kg.")
        return value

    def validate_height(self, value):
        """Ensure height is within a reasonable range"""
        if value is not None and (value < 50 or value > 250):
            raise serializers.ValidationError("Height must be between 50cm and 250cm.")
        return value

    def update(self, instance, validated_data):
        """Custom update method to handle image uploads properly"""
        # Handle image field specifically
        if 'image' in validated_data:
            # Delete old image if it exists and is not the default
            if instance.image and instance.image.name != 'default.jpeg':
                try:
                    instance.image.delete(save=False)
                except:
                    pass  # Handle case where file doesn't exist
            
        # Update all fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        
        instance.save()
        return instance