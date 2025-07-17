from django.shortcuts import render
from rest_framework.generics import GenericAPIView, RetrieveUpdateAPIView
from .serializers import (
    UserRegisterSerializer, VerifyOTPSerializer, LoginSerializer, 
    LogoutUserSerializer, ProfileSerializer, SendResetOTPSerializer,
    ConfirmResetOTPSerializer, ResetPasswordSerializer
)
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from .utlis import send_code_to_user, send_password_reset_code_to_user
from .models import OneTimePassword, User, Profile, PasswordResetOTP
from django.utils.http import urlsafe_base64_decode
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.views import APIView
from rest_framework.decorators import api_view, permission_classes


class RegisterUserView(GenericAPIView):
    permission_classes = [AllowAny]
    serializer_class = UserRegisterSerializer

    def post(self , request , *args , **kwargs):
        user_data = request.data
        serializer = self.serializer_class(data = user_data)

        if serializer.is_valid(raise_exception=True):
            serializer.save()
            user= serializer.data
            send_code_to_user(user['email'])
            return Response({
                'data' : user,
                'message' : f'A verification code has been sent to {user["email"]}'

            } , status= status.HTTP_201_CREATED)

        return Response(serializer.errors , status=status.HTTP_400_BAD_REQUEST)

        

class VerifyUserEmail(GenericAPIView):
    permission_classes = [AllowAny]
    serializer_class = VerifyOTPSerializer  

    def post(self, request):
        serializer = self.get_serializer(data=request.data)  
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        otp_code = serializer.validated_data.get('otp') 

        try:
            otp_entry = OneTimePassword.objects.get(code=otp_code)
            user = otp_entry.user

            if user.is_verified:
                return Response({'message': 'Email already verified.'}, status=status.HTTP_400_BAD_REQUEST)

            # Verify the user
            user.is_verified = True
            user.save()
            otp_entry.delete()

            # Generate authentication tokens
            refresh = RefreshToken.for_user(user)
            access_token = str(refresh.access_token)

            return Response({
                'message': 'Email verified successfully.',
                'access_token': access_token,
                'refresh_token': str(refresh),
            }, status=status.HTTP_200_OK)

        except OneTimePassword.DoesNotExist:
            return Response({'message': 'Invalid OTP code.'}, status=status.HTTP_400_BAD_REQUEST)

class LoginUserView(GenericAPIView):
    permission_classes = [AllowAny]
    serializer_class= LoginSerializer
    def post(self , request , *args , **kwargs):
        serializer = self.serializer_class(data = request.data , context={'request': request})
        serializer.is_valid(raise_exception=True)
        return Response(serializer.data , status=status.HTTP_200_OK)


class SendResetOTPView(APIView):
    permission_classes = [AllowAny]
    serializer_class = SendResetOTPSerializer
    
    def post(self, request):
        serializer = SendResetOTPSerializer(data=request.data)
        if serializer.is_valid():
            email = serializer.validated_data['email']
            result = send_password_reset_code_to_user(email)
            if result['success']:
                return Response({'message': 'OTP sent to your email'}, status=status.HTTP_200_OK)
            else:
                return Response({'error': result['message']}, status=status.HTTP_400_BAD_REQUEST)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ConfirmResetOTPView(APIView):
    permission_classes = [AllowAny]
    serializer_class = ConfirmResetOTPSerializer  

    def post(self, request):
        serializer = ConfirmResetOTPSerializer(data=request.data)  
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        otp_code = serializer.validated_data.get('otp') 

        try:
            otp_entry = PasswordResetOTP.objects.get(code=otp_code)
            user = otp_entry.user

            refresh = RefreshToken.for_user(user)
            access_token = str(refresh.access_token)

            return Response({
                'message': 'OTP verified successfully. You can now reset your password.',
                'access_token': access_token,
                'refresh_token': str(refresh)
            }, status=status.HTTP_200_OK)

        except PasswordResetOTP.DoesNotExist:
            return Response({'message': 'Invalid or expired OTP code.'}, status=status.HTTP_400_BAD_REQUEST)



class ResetPasswordView(APIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ResetPasswordSerializer
    
    def post(self, request):
        serializer = ResetPasswordSerializer(data=request.data)
        if serializer.is_valid():
            new_password = serializer.validated_data['new_password']
            try:
                user = request.user
                user.set_password(new_password)
                user.save()
                
                PasswordResetOTP.objects.filter(user=user).delete()
                
                return Response({
                    'message': 'Password reset successful.'
                }, status=status.HTTP_200_OK)
                
            except Exception as e:
                return Response({'error': 'Failed to reset password'}, status=status.HTTP_400_BAD_REQUEST)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LogoutUserView(GenericAPIView):
    serializer_class = LogoutUserSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response({'message': 'Logout successful'}, status=status.HTTP_200_OK)
    

class ProfileView(RetrieveUpdateAPIView):
    serializer_class = ProfileSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]  # Add parsers for file uploads
    
    def get_object(self):
        """Ensure users can only access their own profile"""
        profile, created = Profile.objects.get_or_create(user=self.request.user)
        return profile

    def get_serializer_context(self):
        """Add request to serializer context for building absolute URLs"""
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def retrieve(self, request, *args, **kwargs):
        """Get user profile"""
        instance = self.get_object()
        serializer = self.get_serializer(instance)
        return Response({
            "message": "Profile retrieved successfully",
            "profile": serializer.data
        }, status=status.HTTP_200_OK)

    def update(self, request, *args, **kwargs):
        """Handle profile updates (both PATCH and PUT)"""
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        
        
        serializer = self.get_serializer(instance, data=request.data, partial=partial)

        if serializer.is_valid():
            serializer.save()
            return Response({
                "message": "Profile updated successfully",
                "profile": serializer.data
            }, status=status.HTTP_200_OK)
        
        return Response({
            "message": "Profile update failed",
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)

    def patch(self, request, *args, **kwargs):
        """Handle PATCH requests"""
        kwargs['partial'] = True
        return self.update(request, *args, **kwargs)