from django.test import TestCase
from django.contrib.auth.models import User
from .models import ConversationSession, ChatMessage

class ChatbotModelsTestCase(TestCase):

    def setUp(self):
        """Create a test user and conversation session before running tests."""
        self.user = User.objects.create_user(username="testuser", password="password123")
        self.session = ConversationSession.objects.create(user=self.user)

    def test_conversation_session_creation(self):
        """Test if a conversation session is created properly."""
        self.assertEqual(ConversationSession.objects.count(), 1)
        self.assertEqual(self.session.user, self.user)

    def test_chat_message_creation(self):
        """Test if a chat message is created properly."""
        msg = ChatMessage.objects.create(
            session=self.session,
            user_input="Hello!",
            ai_response="Hi! How can I help you?",
            language="en"
        )
        self.assertEqual(ChatMessage.objects.count(), 1)
        self.assertEqual(msg.session, self.session)
        self.assertEqual(msg.user_input, "Hello!")
        self.assertEqual(msg.ai_response, "Hi! How can I help you?")
        self.assertEqual(msg.language, "en")

    def test_conversation_deletion_cascades(self):
        """Test if deleting a conversation session deletes its related messages."""
        msg = ChatMessage.objects.create(
            session=self.session,
            user_input="Hello!",
            ai_response="Hi!",
            language="en"
        )
        self.session.delete()
        self.assertEqual(ChatMessage.objects.count(), 0)

    def test_default_language_is_english(self):
        """Test if default language is 'en' when not specified."""
        msg = ChatMessage.objects.create(
            session=self.session,
            user_input="Test message",
            ai_response="Test response"
        )
        self.assertEqual(msg.language, "en")

    def test_ordering_of_messages(self):
        """Test if messages are ordered correctly by timestamp."""
        msg1 = ChatMessage.objects.create(session=self.session, user_input="First", ai_response="Response 1")
        msg2 = ChatMessage.objects.create(session=self.session, user_input="Second", ai_response="Response 2")
        messages = list(ChatMessage.objects.filter(session=self.session))
        self.assertEqual(messages[0], msg1)
        self.assertEqual(messages[1], msg2)

    def test_duplicate_conversation_session_prevention(self):
        """Test that a user can have only one ConversationSession."""
        with self.assertRaises(Exception):
            ConversationSession.objects.create(user=self.user)  # Should fail due to OneToOne constraint
