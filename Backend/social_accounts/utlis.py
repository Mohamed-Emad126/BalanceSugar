# from google.auth.transport import requests
import requests
from google.oauth2 import id_token
from accounts.models import User
from django.contrib.auth import authenticate
from django.conf import settings
from rest_framework.exceptions import AuthenticationFailed





class Google():
    @staticmethod

    def validate(id_token):
        """Validate the Google ID token"""
        GOOGLE_TOKEN_INFO_URL = "https://oauth2.googleapis.com/tokeninfo"

        response = requests.get(GOOGLE_TOKEN_INFO_URL, params={"id_token": id_token})

        try:
            data = response.json()  # ✅ Ensure we return JSON, not a string
            if "error" in data:
                return None  # Invalid token
            return data
        except ValueError:
            return None
        



def login_social_user(email,password):
    
    user = authenticate(email=email , password = password)
    user_tokens = user.tokens()

    return {
            'email': user.email,
            'full_name': user.get_full_name,
            'access_token':str(user_tokens.get('access')),
            'refresh_token': str(user_tokens.get('refresh'))
        }




def register_social_user(provider, email, first_name, last_name):
    user = User.objects.filter(email=email)
    if user.exists():
        if provider == user[0].auth_provider:
            # ✅ Return tokens from login
            return login_social_user(email, settings.SOCIAL_AUTH_PASSWORD)
        else:
            raise AuthenticationFailed(
                detail=f"please continue your login with {user[0].auth_provider}"
            )
    else: 
        new_user = {
            'email': email,
            'first_name': first_name,
            'last_name': last_name,
            'password': settings.SOCIAL_AUTH_PASSWORD
        }
        register_user = User.objects.create_user(**new_user)
        register_user.auth_provider = provider
        register_user.is_verified = True
        register_user.save()
        # ✅ Return tokens from login
        return login_social_user(email=register_user.email, password=settings.SOCIAL_AUTH_PASSWORD)
