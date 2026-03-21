#!/bin/bash

# Salesforce credentials
USERNAME="coreyallen.anderson.98c2aa1c648f@agentforce.com"
PASSWORD="Allie&Layla1"
ORG_URL="https://orgfarm-46fb564a06-dev-ed.develop.my.salesforce.com"

# Get auth token via REST API
echo "Authenticating to Salesforce..."
AUTH_RESPONSE=$(curl -s -X POST "${ORG_URL}/services/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=3MVG9YDQS5WtC11qCq8O7jxC.nA0i.F7hjPmCDcKJYTKFr9v_wNjz74Jvz5Y8WM5B&client_secret=&username=${USERNAME}&password=${PASSWORD}")

ACCESS_TOKEN=$(echo $AUTH_RESPONSE | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo "Authentication failed"
  echo $AUTH_RESPONSE
  exit 1
fi

echo "✓ Authenticated"
echo "Access token: ${ACCESS_TOKEN:0:20}..."

# Deploy using Metadata API
echo "Deploying metadata..."

