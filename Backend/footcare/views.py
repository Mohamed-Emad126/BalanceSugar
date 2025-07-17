import os
import cv2
from django.core.files.storage import FileSystemStorage
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from drf_yasg.utils import swagger_auto_schema
from rest_framework.parsers import MultiPartParser, FormParser
from .models import FootUlcer
from .serializers import FootUlcerSerializer
from .utils import classify_image, apply_segmentation, calculate_ulcer_area
from django.db.models import Max
import numpy as np
from django.utils.text import get_valid_filename
import uuid
from django.core.files.base import ContentFile
import logging




# Directories for uploaded and segmented images
UPLOAD_FOLDER = os.path.join('media', 'uploads')
SEGMENTED_FOLDER = os.path.join(UPLOAD_FOLDER, 'segmented')

os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(SEGMENTED_FOLDER, exist_ok=True)

# 1. Create function (image upload, classification, segmentation, and save the foot ulcer)
@swagger_auto_schema(method='post', request_body=FootUlcerSerializer, responses={201: FootUlcerSerializer, 400: 'Bad Request'})
@parser_classes([MultiPartParser, FormParser])
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_foot_ulcer(request):
    """Create a new foot ulcer record with automatic image processing"""
    if 'image' not in request.FILES:
        return Response({'error': 'Image file is required'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        # Generate unique filenames
        uuid_str = uuid.uuid4().hex[:8]
        image_file = request.FILES['image']
        original_name, ext = os.path.splitext(image_file.name)
        unique_filename = f"{uuid_str}_{get_valid_filename(original_name)}{ext}"
        region = request.data.get('region', 'Foot Ulcer')

        # Read and validate image
        img_bytes = image_file.read()
        img_array = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
        if img is None:
            return Response({'error': 'Invalid or corrupted image file'}, status=status.HTTP_400_BAD_REQUEST)

        # Process image
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        classification_label, confidence = classify_image(img_rgb)
        segmented_img, mask = apply_segmentation(img_rgb, classification_label)
        ulcer_area = calculate_ulcer_area(mask)

        # Save original image
        fs = FileSystemStorage(location=UPLOAD_FOLDER)
        saved_filename = fs.save(unique_filename, ContentFile(img_bytes))
        relative_image_path = os.path.join('uploads', saved_filename)
        # Save segmented image
        segmented_filename = f"segmented_{unique_filename}"
        segmented_path = os.path.join(SEGMENTED_FOLDER, segmented_filename)
        cv2.imwrite(segmented_path, cv2.cvtColor(segmented_img, cv2.COLOR_RGB2BGR))
        relative_segmented_path = os.path.join('uploads', 'segmented', segmented_filename)

        # Track improvement
        previous_ulcer = FootUlcer.objects.filter(
            user=request.user, 
            region=region
        ).order_by('-id').first()
        
        improvement_data = {
            'last_area': None,
            'area_difference': None,
            'improvement_message': None
        }

        if previous_ulcer:
            area_difference = ulcer_area - previous_ulcer.ulcer_area
            improvement_data = {
                'last_area': previous_ulcer.ulcer_area,
                'area_difference': area_difference,
                'improvement_message': "Improvement detected!" if area_difference < 0 
                                    else "Condition not improved"
            }

        # Create record
        foot_ulcer = FootUlcer.objects.create(
            user=request.user,
            image=relative_image_path,
            region=region,
            classification_result=classification_label,
            confidence=confidence,
            segmented_image=relative_segmented_path,
            ulcer_area=ulcer_area,
            **improvement_data
        )

        serializer = FootUlcerSerializer(foot_ulcer, context={'request': request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    except Exception as e:
        return Response(
            {'error': f'Internal server error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

# 2. Retrieve all foot ulcers
@swagger_auto_schema(method='get', responses={200: FootUlcerSerializer(many=True)})
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_all_foot_ulcers(request):
    """Retrieve all foot ulcer records for the authenticated user."""
    foot_ulcers = FootUlcer.objects.filter(user=request.user)
    serializer = FootUlcerSerializer(foot_ulcers, many=True, context={'request': request})
    return Response(serializer.data)

#  3. Retrieve the latest foot ulcer per region
@swagger_auto_schema(method='get', responses={200: FootUlcerSerializer(many=True)})
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_latest_ulcers_per_region(request):
    """Get the latest foot ulcer record for each region for the authenticated user."""
    
    # Get all latest ulcer IDs per region
    latest_ids = (
        FootUlcer.objects
        .filter(user=request.user)
        .values('region')
        .annotate(latest_id=Max('id'))
        .values_list('latest_id', flat=True)
    )

    # Retrieve the actual records
    latest_ulcers = FootUlcer.objects.filter(id__in=latest_ids)
    serializer = FootUlcerSerializer(latest_ulcers, many=True, context={'request': request})
    return Response(serializer.data)


# 3. Retrieve all foot ulcers for a specific region
@swagger_auto_schema(method='get', responses={200: FootUlcerSerializer(many=True)})
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_ulcers_by_region(request):
    """Retrieve all foot ulcer records for a specific region for the authenticated user."""
    region = request.query_params.get('region')

    if not region:
        return Response({'error': 'Region parameter is required.'}, status=400)

    ulcers = FootUlcer.objects.filter(user=request.user, region=region).order_by('-id')
    serializer = FootUlcerSerializer(ulcers, many=True, context={'request': request})
    return Response(serializer.data, status=200)

# 3. Retrieve a specific foot ulcer
@swagger_auto_schema(method='get', responses={200: FootUlcerSerializer, 404: 'Not Found'})
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_foot_ulcer(request, ulcer_id):
    """Retrieve a specific foot ulcer record by ID."""
    try:
        foot_ulcer = FootUlcer.objects.get(id=ulcer_id, user=request.user)
    except FootUlcer.DoesNotExist:
        return Response({'error': 'Foot ulcer not found.'}, status=404)
    
    serializer = FootUlcerSerializer(foot_ulcer, context={'request': request})
    return Response(serializer.data)


# 4. Update foot ulcer record
@swagger_auto_schema(method='put', request_body=FootUlcerSerializer, responses={200: FootUlcerSerializer, 400: 'Bad Request', 404: 'Not Found'})
@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_foot_ulcer(request, ulcer_id):
    """Update an existing foot ulcer record."""
    try:
        foot_ulcer = FootUlcer.objects.get(id=ulcer_id, user=request.user)
    except FootUlcer.DoesNotExist:
        return Response({'error': 'Foot ulcer not found.'}, status=404)
    
    serializer = FootUlcerSerializer(foot_ulcer, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=200)
    return Response(serializer.errors, status=400)


@swagger_auto_schema(method='delete', responses={200: 'All ulcers deleted', 400: 'Bad Request'})
@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_ulcers_by_region(request):
    """Delete all foot ulcer records for a specific region for the authenticated user."""
    region = request.query_params.get('region')

    if not region:
        return Response({'error': 'Region parameter is required.'}, status=400)

    deleted_count, _ = FootUlcer.objects.filter(user=request.user, region=region).delete()

    if deleted_count == 0:
        return Response({'message': f'No ulcers found for region: {region}'}, status=200)

    return Response({'message': f'{deleted_count} ulcer(s) deleted for region: {region}'}, status=200)

# 5. Delete foot ulcer record
@swagger_auto_schema(method='delete', responses={204: 'No Content'})
@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_foot_ulcer(request, ulcer_id):
    """Delete a specific foot ulcer record."""
    try:
        foot_ulcer = FootUlcer.objects.get(id=ulcer_id, user=request.user)
    except FootUlcer.DoesNotExist:
        return Response({'error': 'Foot ulcer not found.'}, status=404)
    
    foot_ulcer.delete()
    return Response({'message': 'Foot ulcer record deleted successfully'}, status=204)





