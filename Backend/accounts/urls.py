from django.urls import path
from .views import RegisterUserView , VerifyUserEmail ,LoginUserView , LogoutUserView , ProfileView
from rest_framework_simplejwt.views import TokenRefreshView
from django.urls import path
from .views import SendResetOTPView, ConfirmResetOTPView, ResetPasswordView



urlpatterns = [
    path('register/', RegisterUserView.as_view(), name='register'),
    path('verify_email/',VerifyUserEmail.as_view(), name='verify_email'),
    path('login/' , LoginUserView.as_view() , name='login'),
    path('send-reset-otp/', SendResetOTPView.as_view(), name='send_reset_otp'),
    path('confirm-reset-otp/', ConfirmResetOTPView.as_view(), name='confirm_reset_otp'), 
    path('reset-password/', ResetPasswordView.as_view(), name='reset_password'),
    path('logout/', LogoutUserView.as_view(), name='logout'),
    path('profile/', ProfileView.as_view(), name='user-profile'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

]