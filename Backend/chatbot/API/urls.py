from django.urls import path ,include
from . import views


app_name = "api"

urlpatterns = [
    path("chatbot/", views.chatbot_api, name="chatbot_api"),
    path('conversations/', views.conversation_list, name='conversation_list'),
    path('conversation/', views.conversation_detail, name='conversation_detail'),
    path('conversation/delete/', views.delete_conversation, name='delete_conversation'),    
]


