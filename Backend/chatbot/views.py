from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.decorators import login_required
from django.core.exceptions import PermissionDenied
import json
from langdetect import detect
import os
from .models import ConversationSession, ChatMessage
from sentence_transformers import SentenceTransformer
from langchain.chains import LLMChain
from langchain_core import prompts
from langchain_google_genai import ChatGoogleGenerativeAI
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np
import pickle
from dotenv import load_dotenv




BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCES_DIR = os.path.join(BASE_DIR,'chatbot', 'resources')
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
def get_user_conversation(user):
    conversation, created = ConversationSession.objects.get_or_create(user=user)
    return conversation

# Function to summarize past messages for context
def generate_conversation_summary(conversation):
    messages = conversation.messages.order_by('timestamp')
    summary = "\n".join([f"User: {msg.user_input}\nAI: {msg.ai_response}" for msg in messages])
    return summary if summary else "No previous conversation history."


@login_required
def conversation_detail(request):
    """Retrieve full chat history for the user"""
    session = get_user_conversation(request.user)
    messages = ChatMessage.objects.filter(session=session).order_by('timestamp')
    
    data = [{
        'input': msg.user_input,
        'response': msg.ai_response,
        'timestamp': msg.timestamp,
        'language': msg.language
    } for msg in messages]
    
    return JsonResponse({'messages': data})

@login_required
def delete_conversation(request):
    """Delete a user's conversation"""
    session = get_user_conversation(request.user)
    ChatMessage.objects.filter(session=session).delete()
    return JsonResponse({"message": "Conversation cleared successfully"})


@csrf_exempt
@login_required
def chatbot(request):
    if request.method == "GET":
        return render(request, 'index.html')

    elif request.method == "POST":
        try:
            data = json.loads(request.body)
            input_text = data.get('input_text')

            if not input_text:
                return JsonResponse({"error": "Missing input text"}, status=400)

            # Retrieve user's conversation
            session = get_user_conversation(request.user)

            # Generate context from past messages
            past_summary = generate_conversation_summary(session)
            
            relevant_chunks = find_most_relevant_chunk(input_text, chunk_embeddings, chunks, top_n=3)
            
            context = past_summary + "\n\n" + "\n\n".join(relevant_chunks)

            # Detect language of user input
            input_language = detect(input_text)

            # Add language instruction to context
            if input_language == "ar":
                context += "\n\nتذكر أن الإجابة يجب أن تكون باللغة العربية فقط."
            elif input_language == "en":
                context += "\n\nRemember to answer in English only."
            # Generate response using AI model

            response = llm_chain.run(context=context, query=input_text)
            

            # Store message
            ChatMessage.objects.create(
                session=session,
                user_input=input_text,
                ai_response=response,
                language=input_language
            )

            return JsonResponse({"response": response })

        except json.JSONDecodeError:
            return JsonResponse({"error": "Invalid JSON format"}, status=400)
        except Exception as e:
            return JsonResponse({"error": f"Processing error: {str(e)}"}, status=500)