from flask import Flask, request, jsonify, render_template_string
import joblib
import numpy as np

# Load model and matrices
clf = joblib.load('DDI_rf_model.pkl')
u = np.load('u_matrix.npy')
vt = np.load('vt_matrix.npy')
drug_index = np.load('drug_index.npy', allow_pickle=True).item()

# Initialize Flask application
app = Flask(__name__)

# Mapping numeric severity predictions to user-friendly messages
severity_messages = {
    3: "Major interaction: These drugs can have serious side effects when taken together. Consult a healthcare provider immediately.",
    2: "Moderate interaction: These drugs may interact and cause noticeable effects. Use caution and seek medical advice if necessary.",
    1: "Minor interaction: The interaction between these drugs is minimal, but you may still experience mild effects.",
    0: "No known interaction: There are no reported interactions between these drugs."
}

def preprocess_input(drug_a, drug_b):
    # Convert drug names to indices using `drug_index`
    idx1 = drug_index.get(drug_a)
    idx2 = drug_index.get(drug_b)
    if idx1 is None or idx2 is None:
        return None
    # Create feature vector by combining corresponding u and vt vectors
    features = np.concatenate([u[idx1], vt[idx2]])
    return features

# HTML form with embedded JavaScript for AJAX
@app.route('/input')
def input_form():
    return '''
    <html>
        <body>
            <h2>Drug Interaction Prediction</h2>
            <form id="predictionForm">
                <label for="drug_a">Enter Drug 1:</label><br>
                <input type="text" id="drug_a" name="drug_a"><br><br>
                <label for="drug_b">Enter Drug 2:</label><br>
                <input type="text" id="drug_b" name="drug_b"><br><br>
                <button type="button" onclick="submitForm()">Submit</button>
            </form>
            <div id="result"></div>
            
            <script>
                function submitForm() {
                    // Get form data
                    const drugA = document.getElementById('drug_a').value;
                    const drugB = document.getElementById('drug_b').value;
                    
                    // Send data to /predict endpoint using AJAX
                    fetch('/predict', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({ drug_a: drugA, drug_b: drugB })
                    })
                    .then(response => response.json())
                    .then(data => {
                        // Display the result
                        if (data.error) {
                            document.getElementById('result').innerHTML = `<p style="color:red;">${data.error}</p>`;
                        } else {
                            document.getElementById('result').innerHTML = `<p>${data.severity}</p>`;
                        }
                    })
                    .catch(error => {
                        document.getElementById('result').innerHTML = `<p style="color:red;">An error occurred: ${error}</p>`;
                    });
                }
            </script>
        </body>
    </html>
    '''

@app.route('/predict', methods=['POST'])
def predict():
    data = request.get_json()
    drug_a = data.get('drug_a')
    drug_b = data.get('drug_b')
    
    # Preprocess the input drugs
    features = preprocess_input(drug_a, drug_b)
    if features is None:
        # Properly structure the JSON response for errors
        return jsonify({'error': 'Drug not found. Please ensure you are entering the generic names of both drugs.'}), 400

    # Make prediction
    severity_prediction = clf.predict([features])[0]
    severity_message = severity_messages.get(severity_prediction, "Unknown interaction level.")
    
    # Return JSON-safe severity message
    return jsonify({'severity': str(severity_message)})



# Run the Flask app
if __name__ == '__main__':
    app.run(debug=True, port=5001)
