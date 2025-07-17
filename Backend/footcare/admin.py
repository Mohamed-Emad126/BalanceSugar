from django.contrib import admin

# Register your models here.
# Register your models here.
# from .models import FootUlcer

from django.core.files.storage import FileSystemStorage
from .models import FootUlcer
import cv2
from .utils import classify_image, apply_segmentation, calculate_ulcer_area
from django.core.exceptions import ValidationError

# تخصيص واجهة الإدارة للنموذج FootUlcer
admin.site.register(FootUlcer)

def save_model(self, request, obj, form, change):
    """أثناء حفظ النموذج، سيتم تحميل الصورة وتطبيق النماذج لحساب التصنيف، التجزئة، والثقة."""
    # إذا كانت الصورة قد تم تحميلها حديثًا
    if obj.image:
        fs = FileSystemStorage()
        file_path = fs.url(obj.image.name)
        
        # محاولة قراءة الصورة
        try:
            img = cv2.imread(file_path)
            if img is None:
                raise ValueError("The image could not be read. Please ensure the image format is supported.")
        except Exception as e:
            raise ValidationError(f"Error reading image: {str(e)}")
        
        # تحويل الصورة للـ RGB والتصنيف
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        classification_label, confidence = classify_image(img_rgb)

        # تطبيق التجزئة
        segmented_img, mask = apply_segmentation(img_rgb)
        segmented_image_path = f"uploads/segmented/segmented_{obj.image.name}"
        cv2.imwrite(segmented_image_path, cv2.cvtColor(segmented_img, cv2.COLOR_RGB2BGR))

        # حساب مساحة القرح
        ulcer_area = calculate_ulcer_area(mask)

        # تعيين القيم المحسوبة للنموذج
        obj.classification_result = classification_label
        obj.confidence = confidence
        obj.segmented_image = segmented_image_path
        obj.ulcer_area = ulcer_area

    else:
        raise ValidationError("No image found for processing.")

    # حفظ السجل بعد تطبيق الحسابات
    super().save_model(request, obj, form, change)