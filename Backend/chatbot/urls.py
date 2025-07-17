from django.urls import path , include
from . import views
urlpatterns = [
    path('', views.chatbot, name='chat_page'),
    path('conversation/', views.conversation_detail, name='conversation_detail'),
    path('conversation/delete/', views.delete_conversation, name='delete_conversation'),
    path("api/", include("chatbot.API.urls", namespace="api")),
]
