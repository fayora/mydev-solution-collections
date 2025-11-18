#!/bin/bash

# A simple script to query an Ollama API endpoint.
#
# Usage:
# 1. Make the script executable:
#    chmod +x ask_llama.sh
#
# 2. Run the script with your prompt:
#    ./ask_llama.sh "Why is the sky blue?"

# --- Configuration ---
# The API endpoint URL. Change this if you are using a different provider.
API_URL="https://ollama-container.whitemushroom-e6d162b3.australiaeast.azurecontainerapps.io/api"
## The list of models: https://ollama.com/search 
# The model to use for generating responses.
MODEL="llama3.2"

# --- Script Logic ---

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Install it using your package manager."
    exit 1
fi

PROMPT="$1"

# First, make Ollama pull the latest model
## Catch errors
MODEL_PULL=$(curl --no-progress-meter -s "$API_URL/pull" -d "{\"model\": \"$MODEL\"}")
if [ $? -ne 0 ]; then
    echo "Error: Failed to pull model."
    exit 1
fi

# Create the JSON payload for the Ollama API with stream set to false
JSON_PAYLOAD=$(printf '{
  "model": "%s",
  "prompt": "%s",
  "stream": false
}' "$MODEL" "$PROMPT")

# Send the request and store the single JSON response from the server
RESPONSE_JSON=$(curl --no-progress-meter "$API_URL/generate" -d "$JSON_PAYLOAD")

# Extract the content from the response.
# The 'jq -r' command extracts the raw string, interpreting \n as newlines.
# The ' // "" ' part handles null values gracefully in case of an error.
RESPONSE_CONTENT=$(echo "$RESPONSE_JSON" | jq -r '.response')

# Print the final, formatted content
echo "$RESPONSE_CONTENT"