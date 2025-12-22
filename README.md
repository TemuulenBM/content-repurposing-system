# AI Video Content Repurposing System

Automated n8n workflow for converting long-form video content into multiple short-form vertical clips optimized for TikTok, Instagram Reels, and YouTube Shorts.

## Features

- 🎬 **Automatic Video Download** - Supports YouTube and other platforms via yt-dlp
- 🎵 **Audio Extraction** - FFmpeg-powered audio processing for transcription
- 📝 **AI Transcription** - OpenAI Whisper for accurate speech-to-text
- 🎯 **Smart Moment Detection** - gpt-5.2-pro identifies the 5 most engaging clips
- ✂️ **Vertical Clip Generation** - Auto-crops to 9:16 aspect ratio
- 📱 **Platform-Specific Captions** - AI-generated hooks and hashtags (gpt-5.2)
- ☁️ **Cloud Storage** - Automatic upload to Cloudflare R2
- 🔄 **Webhook Callback** - Notifies your backend on completion

## Architecture

```
Webhook → Download → Extract Audio → Transcribe → Detect Moments
                                                        ↓
Callback ← Upload R2 ← Generate Captions ← Cut Clips ← Loop
```

## Quick Start

### Prerequisites

- Docker & Docker Compose
- OpenAI API key
- Cloudflare R2 bucket

### Installation

```bash
# Clone the repository
git clone https://github.com/your-repo/content-repurposing-system.git
cd content-repurposing-system

# Configure environment
cp env.example .env
nano .env  # Edit your settings

# Start n8n
docker-compose up -d

# View logs
docker-compose logs -f n8n
```

### Import Workflow

1. Open n8n at `http://localhost:5678`
2. Login with credentials from `.env`
3. Go to **Workflows → Import**
4. Upload `workflow/video-repurposing-workflow.json`
5. Configure credentials (OpenAI, R2)
6. Activate the workflow

### Test the Webhook

```bash
curl -X POST http://localhost:5678/webhook/repurpose-video \
  -H "Content-Type: application/json" \
  -d '{
    "jobId": "test-001",
    "videoUrl": "https://www.youtube.com/watch?v=VIDEO_ID",
    "callbackUrl": "https://your-api.com/callback",
    "platform": "tiktok",
    "style": "educational"
  }'
```

## API Reference

### Input (Webhook POST)

```json
{
  "jobId": "uuid-string",           // Required: Unique job identifier
  "videoUrl": "https://...",        // Required: YouTube or supported URL
  "callbackUrl": "https://...",     // Required: Your callback endpoint
  "platform": "tiktok",             // Optional: tiktok|instagram|youtube_shorts
  "style": "educational"            // Optional: educational|entertainment|motivational
}
```

### Output (Callback POST)

#### Success

```json
{
  "jobId": "uuid",
  "status": "success",
  "processedAt": "2024-01-15T10:30:00.000Z",
  "clipCount": 5,
  "clips": [
    {
      "clipIndex": 1,
      "url": "https://r2.dev/clips/uuid/clip_1.mp4",
      "hook": "This changed everything 🔥",
      "caption": "The advice I needed to hear...",
      "hashtags": ["#fyp", "#viral", "#mindset", "#podcast", "#motivation"]
    }
  ]
}
```

#### Failure

```json
{
  "jobId": "uuid",
  "status": "failed",
  "failedAt": "2024-01-15T10:30:00.000Z",
  "error": {
    "stage": "download",
    "message": "Video unavailable",
    "details": null
  }
}
```

## Configuration

### Required Credentials (in n8n)

| Credential | Type | Description |
|------------|------|-------------|
| OpenAI API | API Key | For Whisper & GPT-4 |
| Cloudflare R2 | AWS S3 Compatible | For clip storage |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `N8N_HOST` | localhost | n8n hostname |
| `N8N_PORT` | 5678 | n8n port |
| `N8N_BASIC_AUTH_USER` | admin | Login username |
| `N8N_BASIC_AUTH_PASSWORD` | - | Login password |
| `TZ` | Asia/Ulaanbaatar | Timezone |

## Documentation

- [Workflow Documentation](docs/WORKFLOW-DOCUMENTATION.md) - Node-by-node explanation
- [FFmpeg Commands](docs/FFMPEG-COMMANDS.md) - Video processing reference
- [GPT Prompts](docs/GPT-PROMPTS.md) - AI prompt templates
- [Error Handling](docs/ERROR-HANDLING.md) - Error handling strategy

## Processing Pipeline

### 1. Video Download (yt-dlp)
Downloads best quality MP4 from supported platforms.

### 2. Audio Extraction (FFmpeg)
Converts to 16kHz mono WAV for Whisper.

### 3. Transcription (Whisper API)
Returns timestamped segments for moment detection.

### 4. Moment Detection (GPT-4)
Identifies 5 most engaging 30-60 second clips.

### 5. Clip Generation (FFmpeg)
- Center crops to 9:16 aspect ratio
- Scales to 1080x1920
- H.264 encoding with AAC audio

### 6. Caption Generation (GPT-4)
Platform-specific hooks, captions, and hashtags.

### 7. Upload & Callback
Uploads to R2 and notifies your backend.

## Performance

| Metric | Typical Value |
|--------|---------------|
| Processing Time | 5-15 minutes |
| Cost per Job | ~$0.04 (GPT) + ~$1.50 (Whisper) |
| Output Clips | 5 clips, 30-60s each |
| Output Quality | 1080x1920, H.264 |

## Troubleshooting

### Common Issues

1. **yt-dlp fails**: Update with `pip install -U yt-dlp`
2. **FFmpeg errors**: Check input video codec
3. **Whisper timeout**: Split long videos (>2 hours)
4. **R2 upload fails**: Verify CORS settings

### Debug Mode

Check n8n execution history for detailed logs.

## License

MIT

