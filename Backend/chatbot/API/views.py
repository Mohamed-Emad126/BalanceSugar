from django.views.decorators.csrf import csrf_exempt
from langdetect import detect
import os
from ..models import ConversationSession, ChatMessage
from sentence_transformers import SentenceTransformer
from langchain import LLMChain
from langchain_core import prompts
from langchain_google_genai import ChatGoogleGenerativeAI
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np
import pickle
from dotenv import load_dotenv
from rest_framework import status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated 
from .serializers import ChatMessageSerializer , ConversationSessionSerializer
from rest_framework.decorators import api_view ,authentication_classes , permission_classes
from drf_yasg import openapi
from drf_yasg.utils import swagger_auto_schema
from django.contrib.auth import get_user_model
from langdetect.lang_detect_exception import LangDetectException
import pytz
from django.utils.timezone import is_naive, make_aware

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCES_DIR = os.path.join(BASE_DIR,'resources')
EMBEDDINGS_FILE = os.path.join(RESOURCES_DIR, 'embeddings.npz')
CHUNKS_FILE = os.path.join(RESOURCES_DIR, 'chunks.pkl')
chunk_embeddings = np.load(EMBEDDINGS_FILE)['embeddings']

with open(CHUNKS_FILE, 'rb') as file:
    chunks = pickle.load(file)
# Load environment variables


# Define the pre-trained embedding model
model = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')

# Define the Google API Key
load_dotenv()
google_api_key = os.getenv("GOOGLE_API_KEY")

# Initialize the GoogleGenerativeAI model using Gemini Flash
llm = ChatGoogleGenerativeAI(
    model="gemini-1.5-flash",
    google_api_key=google_api_key,
    temperature=0 ,  # Control response determinism
    response_moderation=True
)

# AI Prompt Template
template = """ 
You are an AI assistant knowledgeable about diabetes. Your task is to provide accurate, empathetic, and informative answers using the information from the provided context.
- Do not use phrases like "based on the provided context" or "here is a markdown". 
- Start with a short, engaging introduction related to the answer topic. Avoid introducing yourself as an AI assistant.
- Answer thoroughly, referencing specific information from the context whenever possible. 
- If the query is in Arabic, respond in Arabic. If the query is in English, respond in English.
- Return the answer in markdown format for better readability, using bullet points, headings, and lists where appropriate.
- Maintain a compassionate and professional tone, especially when discussing sensitive topics like symptoms, treatments, or complications.
- Avoid medical jargon unless it is explained in simple terms, ensuring accessibility for all users.
- If the response contains redundant numbers, remove them. Keep the answer concise, informative, and on point.
- Avoid duplicating information in the answer.
- Use only the information in the context to formulate your response.
- If the query is unclear or missing details, provide a general answer and suggest asking a more specific question for better guidance.
- Avoid using complex medical terms unless explained in simple language to ensure accessibility for all users.  
- You must refuse to answer any question that is NOT related to diabetes. If a question is unrelated, simply reply: "I'm designed to answer questions related to diabetes only."
- إذا استخدم المريض أو المستخدم كلمات مثل "السكر"، "السكري"، أو "مرض السكر"، تعامل معها جميعًا على أنها تشير إلى "مرض السكري".  
- إذا كان السؤال بالعربية، يجب أن تكون الإجابة بالعربية فقط.
- If you are unable to provide a clear or certain response, or if the user describes severe or urgent symptoms, advise them to consult a healthcare professional or visit a doctor immediately for proper evaluation and care.

Context: {context}

Question: {query}
Answer:
"""
prompt = prompts.PromptTemplate(
    input_variables=["context", "query"]
    , template=template)


llm_chain = LLMChain(
    prompt=prompt,
      llm=llm ,
      )


# Function to find the most relevant chunk
def find_most_relevant_chunk(user_query, chunk_embeddings, chunks, top_n=1):
    # Embed the user's query
    query_embedding = model.encode([user_query])
    
    # Calculate cosine similarity between the query and the chunks
    similarities = cosine_similarity(query_embedding, chunk_embeddings)
    
    # Get the indices of the top N most relevant chunks
    most_relevant_indices = similarities.argsort()[0][-top_n:][::-1]
    
    # Retrieve the most relevant chunks
    relevant_chunks = [chunks[i] for i in most_relevant_indices]
    
    return relevant_chunks


# Function to get or create a user's conversation
User = get_user_model()
def get_user_conversation(user_id):
    user = User.objects.get(id=user_id)
    conversation, created = ConversationSession.objects.get_or_create(user = user)
    return conversation


@api_view(['GET'])
def conversation_list(request):
    sessions = ConversationSession.objects.all()
    serializer = ConversationSessionSerializer(sessions, many=True)
    return Response(serializer.data)

# Function to summarize past messages for context
def generate_conversation_summary(conversation):
    messages = conversation.messages.order_by('timestamp')
    summary = "\n".join([f"User: {msg.user_input}\nAI: {msg.ai_response}" for msg in messages])
    return summary if summary else "No previous conversation history."


import pytz
from django.utils.timezone import is_naive, make_aware

@api_view(['GET'])
def conversation_detail(request):
    user_id = request.user.id
    conversation = get_user_conversation(user_id)
    messages = ChatMessage.objects.filter(session=conversation).order_by('timestamp')

    # Get the user timezone from headers (e.g., 'Africa/Cairo')
    user_tz_str = request.headers.get('User-Timezone', 'UTC')

    try:
        user_tz = pytz.timezone(user_tz_str)
    except pytz.UnknownTimeZoneError:
        return Response({"error": f"Invalid timezone '{user_tz_str}'"}, status=400)

    # Serialize messages manually to include local time
    response_data = []
    for msg in messages:
        timestamp = msg.timestamp
        if is_naive(timestamp):
            timestamp = make_aware(timestamp)

        local_time = timestamp.astimezone(user_tz)
        formatted_time = local_time.strftime("%Y-%m-%d %I:%M %p")  # 12-hour format with AM/PM

        response_data.append({
            "user_input": msg.user_input,
            "ai_response": msg.ai_response,
            "language": msg.language,
            "timestamp": formatted_time
        })

    return Response(response_data)



@api_view(['DELETE'])
def delete_conversation(request):
    user_id = request.user.id
    conversation = get_user_conversation(user_id)
    ChatMessage.objects.filter(session=conversation).delete()
    return Response({"message": "Conversation cleared successfully"}, status=status.HTTP_204_NO_CONTENT)


chatbot_input_schema = openapi.Schema(
    type=openapi.TYPE_OBJECT,
    properties={
        'input_text': openapi.Schema(type=openapi.TYPE_STRING, description="User's input message"),
    },
    required=['input_text']
)

@csrf_exempt
@swagger_auto_schema(method='post', request_body=chatbot_input_schema)
@api_view(['POST'])
def chatbot_api(request):

    data = request.data
    serializer = ChatMessageSerializer(data=data)

    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    input_text = data.get('input_text')
    
    if not input_text:
        return Response({"error": "Missing input text"}, status=status.HTTP_400_BAD_REQUEST)

    # Automatically get the authenticated user
    user = request.user

    # Get or create a conversation session for the user
    session, _ = ConversationSession.objects.get_or_create(user=user)

    # Generate context from past messages
    past_summary = generate_conversation_summary(session)
    
    relevant_chunks = find_most_relevant_chunk(input_text, chunk_embeddings, chunks, top_n=3)
    
    context = past_summary + "\n\n" + "\n\n".join(relevant_chunks)

    # Detect language of user input

    if not input_text.strip():
        return Response({"error": "Input text is empty or invalid."}, status=status.HTTP_400_BAD_REQUEST)

    try:
        input_language = detect(input_text)
    except LangDetectException:
        return Response({"error": "Unable to detect language. Please enter a valid question."}, status=status.HTTP_400_BAD_REQUEST)


    # Add language instruction to context
    if input_language == "ar":
        context += "\n\nتذكر أن الإجابة يجب أن تكون باللغة العربية فقط."
    elif input_language == "en":
        context += "\n\nRemember that the answer should be in English only."


    # Generate response based on context and user input
    response = llm_chain.run(context=context, query=input_text)
    # Save the chat message
    ChatMessage.objects.create(
        session=session,
        user_input=input_text,
        ai_response=response,
        language='en'
    )

    return  Response({"response": response}) 
