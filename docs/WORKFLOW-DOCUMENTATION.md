# Video Content Repurposing Workflow - Full Documentation

## Overview

This n8n workflow automates the process of converting long-form video content into multiple short-form vertical clips optimized for platforms like TikTok, Instagram Reels, and YouTube Shorts.

---

## Architecture Diagram

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────────┐
│   Webhook   │────▶│  Download    │────▶│   Extract   │────▶│  Transcribe  │
│   Trigger   │     │   (yt-dlp)   │     │   Audio     │     │   (Whisper)  │
└─────────────┘     └──────────────┘     └─────────────┘     └──────────────┘
                                                                     │
                                                                     ▼
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────────┐
│   Callback  │◀────│    Upload    │◀────│   Caption   │◀────│   Detect     │
│   to API    │     │    to R2     │     │   (gpt-5.2) │     │   Moments    │
└─────────────┘     └──────────────┘     └─────────────┘     └──────────────┘
                           ▲                    ▲                    │
                           │                    │                    ▼
                           │              ┌─────────────┐     ┌──────────────┐
                           │              │   Parse     │◀────│    Loop      │
                           └──────────────│   Caption   │     │   Moments    │
                                          └─────────────┘     └──────────────┘
                                                 ▲
                                                 │
                                          ┌─────────────┐
                                          │  Cut Clip   │
                                          │  (FFmpeg)   │
                                          └─────────────┘
```

---

## Node-by-Node Explanation

### 1. Webhook Trigger
**Type:** `n8n-nodes-base.webhook`

**Purpose:** Entry point for the workflow. Receives job requests from your backend API.

**Configuration:**
- Method: POST
- Path: `/repurpose-video`
- Response Mode: On Received (immediate acknowledgment)

**Expected Input:**
```json
{
  "jobId": "uuid-string",
  "videoUrl": "https://youtube.com/watch?v=...",
  "callbackUrl": "https://api.myapp.com/callback",
  "platform": "tiktok",
  "style": "educational"
}
```

---

### 2. Validate Input
**Type:** `n8n-nodes-base.if`

**Purpose:** Ensures all required fields are present before processing.

**Conditions:**
- `jobId` is not empty
- `videoUrl` is not empty
- `callbackUrl` is not empty

**Routes:**
- ✅ True → Continue to Set Variables
- ❌ False → Send error callback

---

### 3. Set Variables
**Type:** `n8n-nodes-base.set`

**Purpose:** Normalizes input and sets up working directory.

**Variables Set:**
```javascript
{
  jobId: $json.body.jobId,
  videoUrl: $json.body.videoUrl,
  callbackUrl: $json.body.callbackUrl,
  platform: $json.body.platform || 'tiktok',
  style: $json.body.style || 'educational',
  workDir: `/data/${$json.body.jobId}`
}
```

---

### 4. Download Video (yt-dlp)
**Type:** `n8n-nodes-base.executeCommand`

**Purpose:** Downloads video from YouTube or other supported platforms.

**Command:**
```bash
mkdir -p {{ workDir }} && \
yt-dlp -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best' \
  --merge-output-format mp4 \
  -o '{{ workDir }}/input.mp4' \
  '{{ videoUrl }}' 2>&1 && \
echo 'DOWNLOAD_SUCCESS'
```

**Command Breakdown:**
| Flag | Description |
|------|-------------|
| `-f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best'` | Select best MP4 video + M4A audio, fallback to best available |
| `--merge-output-format mp4` | Ensure final output is MP4 |
| `-o '{{ workDir }}/input.mp4'` | Output path with job-specific directory |
| `2>&1` | Redirect stderr to stdout for error capture |

**Error Handling:**
- Checks for `DOWNLOAD_SUCCESS` in stdout
- On failure, routes to error callback

---

### 5. Extract Audio (FFmpeg)
**Type:** `n8n-nodes-base.executeCommand`

**Purpose:** Extracts audio track and converts to Whisper-compatible format.

**Command:**
```bash
ffmpeg -y -i {{ workDir }}/input.mp4 \
  -vn \
  -acodec pcm_s16le \
  -ar 16000 \
  -ac 1 \
  {{ workDir }}/audio.wav 2>&1 && \
echo 'EXTRACT_SUCCESS'
```

**Command Breakdown:**
| Flag | Description |
|------|-------------|
| `-y` | Overwrite output without asking |
| `-i {{ workDir }}/input.mp4` | Input video file |
| `-vn` | Disable video (audio only) |
| `-acodec pcm_s16le` | Use PCM 16-bit little-endian codec |
| `-ar 16000` | Set sample rate to 16kHz (optimal for Whisper) |
| `-ac 1` | Convert to mono |

---

### 6. Read Audio File
**Type:** `n8n-nodes-base.readWriteFile`

**Purpose:** Reads audio.wav into binary data for API upload.

**Configuration:**
- File Path: `{{ workDir }}/audio.wav`
- MIME Type: `audio/wav`

---

### 7. Transcribe (Whisper API)
**Type:** `n8n-nodes-base.httpRequest`

**Purpose:** Sends audio to OpenAI Whisper for transcription.

**API Endpoint:** `https://api.openai.com/v1/audio/transcriptions`

**Request Configuration:**
```json
{
  "model": "whisper-1",
  "response_format": "verbose_json",
  "timestamp_granularities[]": "segment"
}
```

**Response Format:**
```json
{
  "text": "Full transcript text...",
  "segments": [
    {
      "id": 0,
      "start": 0.0,
      "end": 5.5,
      "text": "Segment text..."
    }
  ]
}
```

---

### 8. Format Transcript
**Type:** `n8n-nodes-base.set`

**Purpose:** Formats transcript data for GPT consumption.

**Output:**
```javascript
{
  transcript: JSON.stringify($json.segments),
  fullText: $json.text
}
```

---

### 9. Detect Key Moments (GPT)
**Type:** `@n8n/n8n-nodes-langchain.openAi`

**Purpose:** Uses gpt-5.2-pro to identify the 5 most engaging moments for short-form content.

**Full Prompt:**
```
You are an expert video content analyst for short-form social media. Your task is to identify the MOST ENGAGING moments from a video transcript that would perform well as standalone vertical clips on {{ platform }}.

The content style is: {{ style }}

ANALYZE THIS TRANSCRIPT:
{{ fullText }}

TIMESTAMPED SEGMENTS:
{{ transcript }}

RULES:
1. Select EXACTLY 5 moments
2. Each clip should be 30-60 seconds long
3. Prioritize moments with:
   - Strong hooks or surprising statements
   - Emotional peaks or revelations
   - Actionable advice or key insights
   - Controversial or debate-worthy points
   - Funny or relatable moments
4. Ensure clips are self-contained and make sense without context
5. Avoid mid-sentence cuts

OUTPUT FORMAT (JSON only, no markdown):
[
  {
    "momentIndex": 1,
    "start": <start_time_in_seconds>,
    "end": <end_time_in_seconds>,
    "reason": "<brief explanation why this moment is engaging>",
    "hookPotential": "<the opening line that hooks viewers>"
  }
]

Return ONLY the JSON array, no other text.
```

**Model Settings:**
- Model: `gpt-5.2-pro`
- Temperature: `0.3` (more deterministic)
- Max Tokens: `2000`

---

### 10. Parse Moments
**Type:** `n8n-nodes-base.code`

**Purpose:** Parses GPT response and prepares moment data for loop processing.

**Code Logic:**
1. Clean markdown formatting from GPT response
2. Parse JSON array
3. Validate each moment has start/end times
4. Add job context to each moment item
5. Return array of moments for loop

---

### 11. Loop Over Moments
**Type:** `n8n-nodes-base.splitInBatches`

**Purpose:** Iterates through each moment one at a time.

**Configuration:**
- Batch Size: `1` (process one clip at a time)

**Outputs:**
- Output 1: Current moment item → Cut Clip
- Output 2: Loop complete → Aggregate Clips

---

### 12. Cut Clip (FFmpeg)
**Type:** `n8n-nodes-base.executeCommand`

**Purpose:** Creates vertical 9:16 clip from the original video.

**Full Command:**
```bash
# Create vertical 9:16 clip with center crop
INPUT="{{ workDir }}/input.mp4"
OUTPUT="{{ workDir }}/clip_{{ clipIndex }}.mp4"
START={{ start }}
DURATION={{ duration }}

# Get video dimensions
WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$INPUT")
HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$INPUT")

# Calculate crop for 9:16 aspect ratio
TARGET_RATIO=0.5625  # 9/16

# Determine crop dimensions (center crop)
if [ $(echo "$WIDTH/$HEIGHT > $TARGET_RATIO" | bc -l) -eq 1 ]; then
  CROP_H=$HEIGHT
  CROP_W=$(echo "$HEIGHT * $TARGET_RATIO" | bc | cut -d. -f1)
else
  CROP_W=$WIDTH
  CROP_H=$(echo "$WIDTH / $TARGET_RATIO" | bc | cut -d. -f1)
fi

# FFmpeg command
ffmpeg -y -ss $START -i "$INPUT" -t $DURATION \
  -vf "crop=${CROP_W}:${CROP_H}:(in_w-${CROP_W})/2:(in_h-${CROP_H})/2,scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2" \
  -c:v libx264 -preset fast -crf 23 \
  -c:a aac -b:a 128k \
  -movflags +faststart \
  "$OUTPUT" 2>&1

if [ -f "$OUTPUT" ]; then
  echo "CLIP_SUCCESS:{{ clipIndex }}"
else
  echo "CLIP_FAILED:{{ clipIndex }}"
fi
```

**FFmpeg Filter Breakdown:**
| Filter | Description |
|--------|-------------|
| `crop=${CROP_W}:${CROP_H}:...` | Center crop to 9:16 aspect ratio |
| `scale=1080:1920:force_original_aspect_ratio=decrease` | Scale to 1080x1920 while maintaining aspect |
| `pad=1080:1920:(ow-iw)/2:(oh-ih)/2` | Add letterboxing if needed |

**Codec Settings:**
| Setting | Description |
|---------|-------------|
| `-c:v libx264` | H.264 video codec (universal compatibility) |
| `-preset fast` | Balance between speed and compression |
| `-crf 23` | Quality level (lower = better, 23 is good balance) |
| `-c:a aac` | AAC audio codec |
| `-b:a 128k` | 128kbps audio bitrate |
| `-movflags +faststart` | Enable fast start for web playback |

---

### 13. Generate Caption (GPT)
**Type:** `@n8n/n8n-nodes-langchain.openAi`

**Purpose:** Creates platform-specific captions, hooks, and hashtags.

**Full Prompt:**
```
You are a viral social media copywriter specializing in {{ platform }} content.

GENERATE CAPTION FOR THIS CLIP:

Clip Context: {{ reason }}
Hook Moment: {{ hookPotential }}
Content Style: {{ style }}
Platform: {{ platform }}

Full Video Context:
{{ fullText (first 1500 chars) }}...

CREATE:
1. HOOK: The first line viewers see (max 10 words, must stop the scroll)
2. CAPTION: 1-2 short lines that add context or create curiosity (casual {{ platform }} tone)
3. HASHTAGS: Exactly 5 relevant hashtags (mix of broad + niche)

PLATFORM GUIDELINES FOR {{ platform.toUpperCase() }}:
- TikTok: Casual, trendy, use slang appropriately, emojis welcome
- Instagram: Slightly more polished, storytelling elements
- YouTube Shorts: Value-focused, clear benefit statement
- Twitter/X: Punchy, controversial hooks work well

OUTPUT FORMAT (JSON only):
{
  "hook": "<scroll-stopping first line>",
  "caption": "<1-2 line caption>",
  "hashtags": ["#tag1", "#tag2", "#tag3", "#tag4", "#tag5"]
}

Return ONLY the JSON object, no other text.
```

**Model Settings:**
- Model: `gpt-5.2`
- Temperature: `0.7` (more creative)
- Max Tokens: `500`

---

### 14. Parse Caption
**Type:** `n8n-nodes-base.code`

**Purpose:** Parses caption response and prepares data for upload.

**Fallback Handling:** If GPT response fails to parse, generates default captions.

---

### 15. Read Clip File
**Type:** `n8n-nodes-base.readWriteFile`

**Purpose:** Reads clip video file into binary for R2 upload.

---

### 16. Upload to R2
**Type:** `n8n-nodes-base.httpRequest`

**Purpose:** Uploads clip to Cloudflare R2 storage.

**Configuration:**
- Method: `PUT`
- URL: `https://{{ accountId }}.r2.cloudflarestorage.com/{{ bucket }}/clips/{{ jobId }}/clip_{{ index }}.mp4`
- Authentication: AWS S3-compatible credentials

---

### 17. Format Clip Result
**Type:** `n8n-nodes-base.code`

**Purpose:** Constructs public URL and formats clip data.

**Output:**
```javascript
{
  clipIndex: 1,
  url: "https://pub-xxx.r2.dev/clips/job-id/clip_1.mp4",
  hook: "This changed everything...",
  caption: "You won't believe what happened next",
  hashtags: ["#viral", "#trending", "#fyp", "#podcast", "#mindset"]
}
```

---

### 18. Aggregate Clips
**Type:** `n8n-nodes-base.aggregate`

**Purpose:** Collects all processed clips into single array after loop completes.

---

### 19. Prepare Callback
**Type:** `n8n-nodes-base.code`

**Purpose:** Constructs final success payload.

**Output:**
```json
{
  "jobId": "uuid",
  "status": "success",
  "processedAt": "2024-01-15T10:30:00.000Z",
  "clipCount": 5,
  "clips": [
    {
      "clipIndex": 1,
      "url": "https://...",
      "hook": "...",
      "caption": "...",
      "hashtags": ["#...", "..."]
    }
  ]
}
```

---

### 20. Send Success Callback
**Type:** `n8n-nodes-base.httpRequest`

**Purpose:** POSTs success payload to the callback URL.

**Configuration:**
- Method: `POST`
- URL: `{{ callbackUrl }}`
- Timeout: 30 seconds

---

### 21. Cleanup Files
**Type:** `n8n-nodes-base.executeCommand`

**Purpose:** Removes temporary files after successful processing.

**Command:**
```bash
rm -rf {{ workDir }} && echo 'CLEANUP_DONE'
```

---

### Error Handling Nodes

#### Download Error / Extract Error
**Type:** `n8n-nodes-base.set`

**Purpose:** Captures stage-specific error information.

#### Prepare Error Callback
**Type:** `n8n-nodes-base.code`

**Purpose:** Constructs error payload.

**Output:**
```json
{
  "jobId": "uuid",
  "status": "failed",
  "failedAt": "2024-01-15T10:30:00.000Z",
  "error": {
    "stage": "download",
    "message": "Failed to download video: ...",
    "details": null
  }
}
```

#### Send Error Callback
**Type:** `n8n-nodes-base.httpRequest`

**Purpose:** POSTs error payload to callback URL.

---

## Credentials Setup

### 1. OpenAI API Credentials

In n8n:
1. Go to Settings → Credentials
2. Add new credential: **OpenAI API**
3. Enter your API key

### 2. Cloudflare R2 Credentials

In n8n:
1. Go to Settings → Credentials
2. Add new credential: **AWS** (R2 is S3-compatible)
3. Configure:
   - Access Key ID: Your R2 access key
   - Secret Access Key: Your R2 secret key
   - Region: `auto`
   - Custom Endpoint: `https://<account-id>.r2.cloudflarestorage.com`

---

## Deployment

### Start the System

```bash
# Copy environment file
cp env.example .env

# Edit configuration
nano .env

# Start n8n
docker-compose up -d

# View logs
docker-compose logs -f n8n
```

### Import Workflow

1. Open n8n at `http://localhost:5678`
2. Go to Workflows → Import
3. Upload `workflow/video-repurposing-workflow.json`
4. Configure credentials in each node
5. Activate the workflow

### Test Webhook

```bash
curl -X POST http://localhost:5678/webhook/repurpose-video \
  -H "Content-Type: application/json" \
  -d '{
    "jobId": "test-001",
    "videoUrl": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    "callbackUrl": "https://webhook.site/your-id",
    "platform": "tiktok",
    "style": "entertainment"
  }'
```

---

## Performance Considerations

### Resource Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8+ GB |
| Storage | 50 GB | 100+ GB SSD |

### Optimization Tips

1. **Parallel Processing:** For high volume, run multiple n8n workers
2. **Storage:** Use SSD for /data directory
3. **Cleanup:** The workflow automatically cleans up after success
4. **Queue:** Use n8n's queue mode for production

---

## Troubleshooting

### Common Issues

1. **yt-dlp fails:** Update yt-dlp regularly (`pip install -U yt-dlp`)
2. **FFmpeg errors:** Check input video codec compatibility
3. **Whisper timeout:** For very long videos (>2 hours), consider chunking audio
4. **R2 upload fails:** Verify CORS settings on bucket

### Debug Mode

Enable execution saving in workflow settings to inspect failed runs.

