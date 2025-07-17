from django.db import models
from accounts.models import User

class ConversationSession(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="conversation")
    created_at = models.DateTimeField(auto_now_add=True)
    last_updated = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.email}'s Conversation"

class ChatMessage(models.Model):
    session = models.ForeignKey(ConversationSession, on_delete=models.CASCADE, related_name='messages')
    user_input = models.TextField()
    ai_response = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)
    language = models.CharField(max_length=2, default='en')  # 'en' or 'ar'

    class Meta:
        ordering = ['timestamp']

    def __str__(self):
        return f"Message in {self.session.user.email}'s Conversation"
