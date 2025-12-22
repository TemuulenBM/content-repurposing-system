#!/bin/bash

# Test script for the video repurposing workflow
# Usage: ./scripts/test-webhook.sh [VIDEO_URL] [CALLBACK_URL]

set -e

# Configuration
N8N_HOST="${N8N_HOST:-http://localhost:5678}"
WEBHOOK_PATH="/webhook/repurpose-video"

# Generate unique job ID
JOB_ID="test-$(date +%s)-$(openssl rand -hex 4)"

# Default test values
VIDEO_URL="${1:-https://www.youtube.com/watch?v=dQw4w9WgXcQ}"
CALLBACK_URL="${2:-https://webhook.site/$(openssl rand -hex 16)}"
PLATFORM="${3:-tiktok}"
STYLE="${4:-entertainment}"

echo "========================================"
echo "Video Repurposing Workflow Test"
echo "========================================"
echo ""
echo "Configuration:"
echo "  n8n Host:     $N8N_HOST"
echo "  Job ID:       $JOB_ID"
echo "  Video URL:    $VIDEO_URL"
echo "  Callback URL: $CALLBACK_URL"
echo "  Platform:     $PLATFORM"
echo "  Style:        $STYLE"
echo ""
echo "========================================"
echo "Sending webhook request..."
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${N8N_HOST}${WEBHOOK_PATH}" \
  -H "Content-Type: application/json" \
  -d "{
    \"jobId\": \"$JOB_ID\",
    \"videoUrl\": \"$VIDEO_URL\",
    \"callbackUrl\": \"$CALLBACK_URL\",
    \"platform\": \"$PLATFORM\",
    \"style\": \"$STYLE\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n -1)

echo "Response Code: $HTTP_CODE"
echo "Response Body: $BODY"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ Webhook triggered successfully!"
  echo ""
  echo "Monitor the job:"
  echo "  - n8n Executions: ${N8N_HOST}/executions"
  echo "  - Callback URL:   $CALLBACK_URL"
else
  echo "❌ Webhook failed with status $HTTP_CODE"
  exit 1
fi

