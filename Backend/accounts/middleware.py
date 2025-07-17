import pytz
from django.utils import timezone

class TimezoneMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        tzname = request.headers.get("User-Timezone", "UTC")
        try:
            user_timezone = pytz.timezone(tzname)
        except pytz.UnknownTimeZoneError:
            user_timezone = pytz.UTC
        
        request.user_timezone = user_timezone
        response = self.get_response(request)
        return response 