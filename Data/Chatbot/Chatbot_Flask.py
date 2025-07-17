import pickle
import numpy as np
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain import PromptTemplate, LLMChain
from flask import Flask, request, jsonify
import os
from dotenv import load_dotenv
from datetime import datetime
from langdetect import detect

# Load embeddings and chunks from pre-saved files
embeddings_file_path = "Data/Chatbot/embeddings.npz"
chunks_file_path = "Data/Chatbot/chunks.pkl"
memory_file_path = "Data/Chatbot/session_memory.pkl"  # File to store session memory

# Load chunk embeddings
chunk_embeddings = np.load(embeddings_file_path)['embeddings']

# Load chunks
with open(chunks_file_path, 'rb') as file:
    chunks = pickle.load(file)

# Define the pre-trained embedding model
model = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')

# Define the Google API Key
load_dotenv()
google_api_key = os.getenv("GOOGLE_API_KEY")

# Initialize the GoogleGenerativeAI model using Gemini Flash
llm = ChatGoogleGenerativeAI(
    model="gemini-1.5-flash",
    google_api_key=google_api_key,
    temperature=0  # Control response determinism
)

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
- If the query is related to diabetes but the model cannot provide an answer, use Gemini to retrieve accurate information. 
- إذا استخدم المريض أو المستخدم كلمات مثل "السكر"، "السكري"، أو "مرض السكر"، تعامل معها جميعًا على أنها تشير إلى "مرض السكري".  
- إذا كان السؤال بالعربية، يجب أن تكون الإجابة بالعربية فقط.
- If you are unable to provide a clear or certain response, or if the user describes severe or urgent symptoms, advise them to consult a healthcare professional or visit a doctor immediately for proper evaluation and care.

Context: {context}

Question: {query}
Answer:
"""

prompt = PromptTemplate(
    input_variables=["context", "query"],
    template=template,
)

llm_chain = LLMChain(
    prompt=prompt,
    llm=llm,
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

# Function to load session memory
def load_session_memory():
    if os.path.exists(memory_file_path):
        with open(memory_file_path, 'rb') as file:
            session_data = pickle.load(file)
            return session_data.get('memory', {})
    else:
        return {}

# Function to save session memory
def save_session_memory(session_memory):
    session_data = {
        'memory': session_memory,
        'last_cleared': datetime.now().strftime("%Y-%m-%d %H:%M:%S")  # تحديث تاريخ آخر مسح
    }
    with open(memory_file_path, 'wb') as file:
        pickle.dump(session_data, file)

# Function to clear session memory manually
def clear_session_memory(session_id, session_memory):
    if session_id in session_memory:
        session_memory[session_id] = []  # Clear specific session memory
        save_session_memory(session_memory)
        return "Session memory cleared successfully."
    return "Session not found."

# Flask app setup
app = Flask(__name__)

@app.route('/chatbot', methods=['POST'])
def chatbot():
    data = request.json
    input_text = data.get('input_text')
    session_id = data.get('session_id')
    clear_memory = data.get('clear_memory', False)
    
    # Load session memory
    session_memory = load_session_memory()

    # Option to clear memory
    if clear_memory:
        message = clear_session_memory(session_id, session_memory)
        return jsonify({"message": message})

    # Initialize session memory for new sessions
    if session_id not in session_memory:
        session_memory[session_id] = []

    # Find relevant chunks
    relevant_chunks = find_most_relevant_chunk(input_text, chunk_embeddings, chunks, top_n=3)

    # Combine previous chat history as context
    chat_history = "\n\n".join(session_memory[session_id])
    context = chat_history + "\n\n" + "\n\n".join(relevant_chunks)

    # Detect the input language
    input_language = detect(input_text)
    
    # Add a note in the context to enforce language consistency
    if input_language == "ar":
        context += "\n\nتذكر أن الإجابة يجب أن تكون باللغة العربية فقط."
    elif input_language == "en":
        context += "\n\nRemember to answer in English only."

    # Generate response
    response = llm_chain.run(context=context, query=input_text)

    # Update session memory
    session_memory[session_id].append(f"User: {input_text}\nAI: {response}")

    # Save updated session memory
    save_session_memory(session_memory)

    return jsonify({"response": response})

if __name__ == '__main__':
    app.run(debug=True, port=5000)
