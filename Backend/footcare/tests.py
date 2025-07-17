from django.test import TestCase
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model

class FootUlcerAPITest(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username='testuser', password='password123')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_create_foot_ulcer(self):
        image = SimpleUploadedFile("E:\image.jpg", b"file_content", content_type="image/jpg")
        response = self.client.post(
            '/footcare/ulcers/create/',
            {'image': image, 'region': 'Left Foot'},
            format='multipart'
        )
        self.assertEqual(response.status_code, 201)
        self.assertIn('segmented_image_url', response.data)