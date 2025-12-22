# Error Handling Strategy

## Overview

This document outlines the comprehensive error handling strategy for the Video Content Repurposing workflow. The system is designed to be **fail-fast** with proper error reporting to the callback URL.

---

## Error Handling Philosophy

### Principles

1. **Fail Fast:** Don't continue processing if a critical step fails
2. **Always Callback:** Whether success or failure, always notify the backend
3. **Capture Context:** Include stage, message, and details in error reports
4. **Cleanup on Success:** Remove temporary files only after successful completion
5. **Preserve on Failure:** Keep files for debugging when errors occur

---

## Error Categories

### 1. Validation Errors

**Stage:** Input Validation

**Triggers:**
- Missing `jobId`
- Missing `videoUrl`
- Missing `callbackUrl`

**Handling:**
```javascript
// IF node checks all required fields
conditions: [
  { field: "jobId", operator: "notEmpty" },
  { field: "videoUrl", operator: "notEmpty" },
  { field: "callbackUrl", operator: "notEmpty" }
]
```

**Response:**
```json
{
  "jobId": "unknown",
  "status": "failed",
  "error": {
    "stage": "validation",
    "message": "Missing required fields: jobId, videoUrl, or callbackUrl"
  }
}
```

---

### 2. Download Errors

**Stage:** Video Download (yt-dlp)

**Common Causes:**
- Invalid URL
- Private/deleted video
- Geographic restrictions
- Rate limiting
- Network issues

**Detection:**
```bash
# Command includes success marker
yt-dlp ... && echo 'DOWNLOAD_SUCCESS'

# Check for marker in output
if stdout.contains('DOWNLOAD_SUCCESS') → success
else → error
```

**Response:**
```json
{
  "jobId": "uuid",
  "status": "failed",
  "error": {
    "stage": "download",
    "message": "Failed to download video: Video unavailable"
  }
}
```

**Retry Strategy:**
- **Recommended:** No automatic retry in workflow
- **Backend:** Implement retry with exponential backoff (1min, 5min, 15min)
- **Max Retries:** 3

---

### 3. Audio Extraction Errors

**Stage:** FFmpeg Audio Extraction

**Common Causes:**
- Corrupted video file
- Unsupported codec
- Disk space issues
- Permission errors

**Detection:**
```bash
# Command includes success marker
ffmpeg ... && echo 'EXTRACT_SUCCESS'

# Check for marker in output
if stdout.contains('EXTRACT_SUCCESS') → success
else → error
```

**Response:**
```json
{
  "jobId": "uuid",
  "status": "failed",
  "error": {
    "stage": "audio_extraction",
    "message": "Failed to extract audio: Invalid data found when processing input"
  }
}
```

---

### 4. Transcription Errors

**Stage:** OpenAI Whisper API

**Common Causes:**
- Audio too long (>25MB limit)
- Invalid audio format
- API rate limiting
- API key issues

**Built-in Handling:**
- Timeout set to 300 seconds (5 minutes)
- n8n will capture HTTP errors automatically

**Response:**
```json
{
  "jobId": "uuid",
  "status": "failed",
  "error": {
    "stage": "transcription",
    "message": "Whisper API error: Rate limit exceeded"
  }
}
```

**Retry Strategy:**
- Rate limit: Retry after `Retry-After` header value
- Timeout: Retry once with doubled timeout

---

### 5. GPT Analysis Errors

**Stage:** Key Moment Detection / Caption Generation

**Common Causes:**
- Invalid JSON response
- API rate limiting
- Context length exceeded
- Content policy violation

**Built-in Handling:**
```javascript
// Parse Moments node handles JSON parsing errors
try {
  const moments = JSON.parse(cleanedResponse);
  // validate...
} catch (e) {
  throw new Error(`Failed to parse GPT response: ${e.message}`);
}

// Parse Caption has fallback
catch (e) {
  // Return default captions instead of failing
  return {
    hook: "You need to see this 👀",
    caption: "Watch till the end!",
    hashtags: ["#viral", "#foryou", "#trending", "#mustwatch", "#fyp"]
  };
}
```

**Caption Fallback:** The caption generation has a built-in fallback to prevent entire job failure for non-critical errors.

---

### 6. Video Processing Errors

**Stage:** FFmpeg Clip Cutting

**Common Causes:**
- Invalid timestamp (beyond video length)
- Codec incompatibility
- Disk space issues
- Memory exhaustion

**Detection:**
```bash
if [ -f "$OUTPUT" ]; then
  echo "CLIP_SUCCESS:{{ clipIndex }}"
else
  echo "CLIP_FAILED:{{ clipIndex }}"
fi
```

**Partial Success Handling:**
- Workflow continues with remaining clips
- Failed clips are excluded from final output
- Callback indicates partial success if some clips succeeded

---

### 7. Upload Errors

**Stage:** Cloudflare R2 Upload

**Common Causes:**
- Invalid credentials
- Bucket permissions
- File size limits
- Network issues

**Built-in Handling:**
- `neverError: true` prevents workflow halt
- Response status checked in next node

**Response:**
```json
{
  "jobId": "uuid",
  "status": "partial_success",
  "error": {
    "stage": "upload",
    "failedClips": [3, 5],
    "message": "Failed to upload some clips"
  }
}
```

---

### 8. Callback Errors

**Stage:** Success/Error Callback

**Common Causes:**
- Backend unavailable
- Invalid callback URL
- Timeout

**Built-in Handling:**
- `neverError: true` prevents infinite error loop
- 30 second timeout

**Logging:**
- Execution is marked complete regardless of callback result
- Failed callbacks are logged in n8n execution history

---

## Error Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        MAIN FLOW                                │
└─────────────────────────────────────────────────────────────────┘
         │                    │                     │
         ▼                    ▼                     ▼
    ┌─────────┐          ┌─────────┐          ┌─────────┐
    │ Stage 1 │          │ Stage 2 │          │ Stage N │
    │ Error?  │          │ Error?  │          │ Error?  │
    └────┬────┘          └────┬────┘          └────┬────┘
         │ Yes                │ Yes                │ Yes
         ▼                    ▼                    ▼
    ┌─────────────────────────────────────────────────────┐
    │                 SET ERROR CONTEXT                    │
    │  - errorStage: "download" | "extraction" | etc.     │
    │  - errorMessage: stderr or stdout content           │
    └─────────────────────────────────────────────────────┘
                              │
                              ▼
    ┌─────────────────────────────────────────────────────┐
    │              PREPARE ERROR CALLBACK                  │
    │  {                                                   │
    │    jobId: "...",                                     │
    │    status: "failed",                                 │
    │    failedAt: "ISO timestamp",                        │
    │    error: { stage, message, details }                │
    │  }                                                   │
    └─────────────────────────────────────────────────────┘
                              │
                              ▼
    ┌─────────────────────────────────────────────────────┐
    │               SEND ERROR CALLBACK                    │
    │  POST {{ callbackUrl }}                              │
    │  (neverError: true - don't fail on callback error)  │
    └─────────────────────────────────────────────────────┘
                              │
                              ▼
                        [ WORKFLOW END ]
```

---

## Implementing Retry Logic (Backend)

Since the workflow is stateless and idempotent, retry logic should be implemented in your backend:

```javascript
// Example: Backend retry handler
async function handleJobCallback(payload) {
  if (payload.status === 'success') {
    await saveClips(payload.clips);
    await notifyUser(payload.jobId, 'complete');
    return;
  }
  
  // Handle failure
  const job = await getJob(payload.jobId);
  
  if (job.retryCount < 3) {
    // Calculate backoff
    const delayMs = Math.pow(2, job.retryCount) * 60000; // 1m, 2m, 4m
    
    // Schedule retry
    await scheduleRetry(payload.jobId, delayMs);
    await updateJob(payload.jobId, { 
      retryCount: job.retryCount + 1,
      lastError: payload.error 
    });
  } else {
    // Max retries exceeded
    await updateJob(payload.jobId, { 
      status: 'permanently_failed',
      lastError: payload.error 
    });
    await notifyUser(payload.jobId, 'failed');
  }
}
```

---

## Idempotency Guarantees

The workflow is designed to be safely re-runnable:

1. **Directory Creation:** `mkdir -p` is idempotent
2. **File Overwrite:** FFmpeg `-y` flag overwrites existing files
3. **R2 Upload:** PUT operation overwrites existing objects
4. **Unique Paths:** All paths include `jobId` for isolation

**Safe to Retry:** Yes, re-triggering with same `jobId` will overwrite previous attempt.

---

## Monitoring & Alerting

### Recommended Metrics

1. **Execution Success Rate**
   - Target: >95%
   - Alert: <90% over 1 hour

2. **Average Processing Time**
   - Target: <10 minutes per job
   - Alert: >20 minutes

3. **Error by Stage Distribution**
   - Track which stages fail most
   - Focus optimization efforts

### n8n Execution Logs

Enable execution saving:
```json
{
  "settings": {
    "saveExecutionProgress": true,
    "saveManualExecutions": true
  }
}
```

---

## Debug Checklist

When investigating failures:

1. **Check n8n Execution History**
   - Find the failed execution
   - Review node-by-node output

2. **Verify Credentials**
   - OpenAI API key valid?
   - R2 credentials correct?

3. **Check Disk Space**
   ```bash
   df -h /data
   ```

4. **Check Container Resources**
   ```bash
   docker stats n8n-video-repurpose
   ```

5. **Test yt-dlp Manually**
   ```bash
   docker exec -it n8n-video-repurpose yt-dlp --version
   docker exec -it n8n-video-repurpose yt-dlp -F "VIDEO_URL"
   ```

6. **Test FFmpeg Manually**
   ```bash
   docker exec -it n8n-video-repurpose ffmpeg -version
   ```

7. **Review Temporary Files**
   ```bash
   ls -la /data/{jobId}/
   ```

