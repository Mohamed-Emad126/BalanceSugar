from django.shortcuts import render
from rest_framework.generics import GenericAPIView
from .serializers import GoogleSignInSerializer
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny
from allauth.socialaccount.providers.google.views import GoogleOAuth2Adapter


# Create your views here.



class GoogleSignInView(GenericAPIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    serializer_class = GoogleSignInSerializer

    def post(self, request, *args, **kwargs):
        serializer = GoogleSignInSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        # ✅ Correctly extract the user data from the validated serializer
        user_data = serializer.validated_data

        return Response({
            "message": "Login successful",
            "access_token": user_data.get("access_token"),
            "refresh_token": user_data.get("refresh_token"),
            "email": user_data.get("email"),
            "first_name": user_data.get("first_name"),
            "last_name": user_data.get("last_name"),
        }, status=status.HTTP_200_OK)
