from rest_framework import serializers
from .utlis import Google , register_social_user
from django.conf import settings
from rest_framework.exceptions import AuthenticationFailed






class GoogleSignInSerializer(serializers.Serializer):
    id_token = serializers.CharField()

    def validate(self, attrs):
        id_token = attrs.get("id_token")

        google_user_data = Google.validate(id_token)

        # ✅ Ensure we have a valid response
        if not google_user_data:
            raise serializers.ValidationError("Invalid or expired token")

        if not isinstance(google_user_data, dict):  # ✅ Ensure it's a dictionary
            raise serializers.ValidationError("Invalid response from Google")

        if "aud" not in google_user_data:
            raise serializers.ValidationError("Invalid token: missing audience")

        # Validate audience (aud)
        if google_user_data["aud"] != settings.GOOGLE_CLIENT_ID:
            raise AuthenticationFailed("Invalid token: wrong audience")

        # Extract user data
        email = google_user_data.get("email")
        first_name = google_user_data.get("given_name")
        last_name = google_user_data.get("family_name")
        provider = "google"

        # Register or authenticate user
        user_data = register_social_user(provider, email, first_name, last_name)
        

        # ✅ Return validated user data
        return {
        "email": email,
        "first_name": first_name,
        "last_name": last_name,
        "provider": provider,
        "access_token": user_data.get("access_token"),  # Add this
        "refresh_token": user_data.get("refresh_token")  # Add this
    }