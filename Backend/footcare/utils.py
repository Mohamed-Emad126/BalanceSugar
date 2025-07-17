import cv2
import numpy as np
import tensorflow as tf

# Load models for classification and segmentation
classification_model = tf.keras.models.load_model("footcare/model/Diabetic_Foot_Ulcer4.h5", compile=False)
classification_model.compile(optimizer="adam", loss="categorical_crossentropy", metrics=["accuracy"])

segmentation_model = tf.keras.models.load_model("footcare/model/ulcer_segmentation_model.h5", compile=False)

def preprocess_image(img, img_size=(224, 224)):
    """Preprocess image for classification"""
    img = cv2.resize(img, img_size)
    img = img.astype(np.float32) / 127.5 - 1  # Normalize [-1,1]
    img = np.expand_dims(img, axis=0)
    return img

def classify_image(img):
    """Classify the image as normal or ulcer"""
    img_preprocessed = preprocess_image(img)
    predictions = classification_model.predict(img_preprocessed)
    normal_prob, ulcer_prob = predictions[0]

    if ulcer_prob > 0.6:
        return "Abnormal (Ulcer)", ulcer_prob
    elif normal_prob > 0.6:
        return "Normal (Healthy Skin)", normal_prob
    return "Uncertain", max(normal_prob, ulcer_prob)

def apply_segmentation(img, classification_label): 
    """Segment ulcer area and color the mask based on classification"""
    img_resized = cv2.resize(img, (224, 224)) / 255.0
    img_resized = np.expand_dims(img_resized, axis=0)
    mask = segmentation_model.predict(img_resized)[0]
    mask = (mask > 0.5).astype(np.uint8)
    mask = cv2.resize(mask, (img.shape[1], img.shape[0]))

    # Color: green for normal, red for ulcer
    if classification_label == "Normal (Healthy Skin)":
        color = (0, 255, 0)  # Green
    else:
        color = (255,0,0
                 )  # Red

    color_mask = np.zeros_like(img, dtype=np.uint8)
    color_mask[:, :] = color

    overlay = cv2.addWeighted(img, 0.7, color_mask, 0.3, 0)
    result = img.copy()
    result[mask > 0] = overlay[mask > 0]

    return result, mask


def calculate_ulcer_area(mask, pixel_to_mm_ratio=1.0):
    """Calculate ulcer area in mm²"""
    return np.sum(mask > 0) * pixel_to_mm_ratio

# import cv2
# import numpy as np
# import tensorflow as tf

# # Load models for classification and segmentation
# classification_model = tf.keras.models.load_model("footcare/model/Diabetic_Foot_Ulcer4.h5", compile=False)
# classification_model.compile(optimizer="adam", loss="categorical_crossentropy", metrics=["accuracy"])

# segmentation_model = tf.keras.models.load_model("footcare/model/ulcer_segmentation_model.h5", compile=False)

# def preprocess_image(img, img_size=(224, 224)):
#     """Preprocess image for classification"""
#     img = cv2.resize(img, img_size)
#     img = img.astype(np.float32) / 127.5 - 1  # Normalize [-1,1]
#     img = np.expand_dims(img, axis=0)
#     return img

# def classify_image(img):
#     """Classify the image as normal or ulcer"""
#     img_preprocessed = preprocess_image(img)
#     predictions = classification_model.predict(img_preprocessed)
#     normal_prob, ulcer_prob = predictions[0]
#     if ulcer_prob > 0.6:
#         return "Abnormal (Ulcer)", ulcer_prob
#     elif normal_prob > 0.6:
#         return "Normal (Healthy Skin)", normal_prob
#     return "Uncertain", max(normal_prob, ulcer_prob)

# def apply_segmentation(img):
#     """Segment ulcer area"""
#     img_resized = cv2.resize(img, (224, 224)) / 255.0
#     img_resized = np.expand_dims(img_resized, axis=0)
#     mask = segmentation_model.predict(img_resized)[0]
#     mask = (mask > 0.5).astype(np.uint8)
#     mask = cv2.resize(mask, (img.shape[1], img.shape[0]))
#     return mask

# def calculate_ulcer_area(mask, pixel_to_mm_ratio=1.0):
#     """Calculate ulcer area in mm²"""
#     return np.sum(mask > 0) * pixel_to_mm_ratio


