from django.contrib import admin
from .models import ConversationSession,  ChatMessage


# Register your models here.
admin.site.register(ConversationSession)
admin.site.register(ChatMessage)
