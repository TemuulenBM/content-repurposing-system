# FFmpeg Commands Reference

This document contains all FFmpeg commands used in the workflow with detailed explanations.

---

## 1. Audio Extraction Command

**Purpose:** Extract audio from video and convert to Whisper-compatible format.

```bash
ffmpeg -y -i /data/{jobId}/input.mp4 \
  -vn \
  -acodec pcm_s16le \
  -ar 16000 \
  -ac 1 \
  /data/{jobId}/audio.wav
```

### Parameters Explained

| Parameter | Value | Description |
|-----------|-------|-------------|
| `-y` | - | Overwrite output file without asking |
| `-i` | `/data/{jobId}/input.mp4` | Input video file |
| `-vn` | - | Disable video stream (audio only) |
| `-acodec` | `pcm_s16le` | Audio codec: PCM signed 16-bit little-endian |
| `-ar` | `16000` | Audio sample rate: 16kHz (optimal for Whisper) |
| `-ac` | `1` | Audio channels: 1 (mono) |

### Why These Settings?

- **16kHz Sample Rate:** Whisper was trained on 16kHz audio. Higher rates don't improve quality but increase file size.
- **Mono:** Speech recognition doesn't benefit from stereo.
- **PCM:** Uncompressed audio ensures no quality loss for transcription.
- **WAV Format:** Wide compatibility with Whisper API.

### Output Size Estimation

```
Duration (seconds) × 16000 (sample rate) × 2 (bytes per sample) = File size in bytes

Example: 10 minute video
600 × 16000 × 2 = 19.2 MB
```

---

## 2. Video Clip Cutting Command

**Purpose:** Extract a segment and convert to 9:16 vertical format.

```bash
# Get source dimensions
WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "input.mp4")
HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "input.mp4")

# Calculate 9:16 crop
TARGET_RATIO=0.5625  # 9/16

if [ $(echo "$WIDTH/$HEIGHT > $TARGET_RATIO" | bc -l) -eq 1 ]; then
  # Source is wider than 9:16 - crop width
  CROP_H=$HEIGHT
  CROP_W=$(echo "$HEIGHT * $TARGET_RATIO" | bc | cut -d. -f1)
else
  # Source is taller than 9:16 - crop height
  CROP_W=$WIDTH
  CROP_H=$(echo "$WIDTH / $TARGET_RATIO" | bc | cut -d. -f1)
fi

# Main FFmpeg command
ffmpeg -y -ss {START} -i input.mp4 -t {DURATION} \
  -vf "crop=${CROP_W}:${CROP_H}:(in_w-${CROP_W})/2:(in_h-${CROP_H})/2,scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2" \
  -c:v libx264 -preset fast -crf 23 \
  -c:a aac -b:a 128k \
  -movflags +faststart \
  output.mp4
```

### Video Filter Chain Explained

```
crop → scale → pad
```

#### Filter 1: crop

```
crop=${CROP_W}:${CROP_H}:(in_w-${CROP_W})/2:(in_h-${CROP_H})/2
```

| Component | Description |
|-----------|-------------|
| `${CROP_W}` | Output width (calculated for 9:16) |
| `${CROP_H}` | Output height (calculated for 9:16) |
| `(in_w-${CROP_W})/2` | X offset (centers crop horizontally) |
| `(in_h-${CROP_H})/2` | Y offset (centers crop vertically) |

**Visual Example (16:9 → 9:16):**
```
Input (1920x1080):
┌─────────────────────────────────────┐
│     │                         │     │
│     │    Visible Area         │     │
│     │    (607.5 x 1080)       │     │
│     │                         │     │
└─────────────────────────────────────┘
      ↑ crop starts here

Output crop dimensions: 607.5 x 1080
```

#### Filter 2: scale

```
scale=1080:1920:force_original_aspect_ratio=decrease
```

| Component | Description |
|-----------|-------------|
| `1080` | Target width |
| `1920` | Target height |
| `force_original_aspect_ratio=decrease` | Scale down to fit within bounds |

#### Filter 3: pad

```
pad=1080:1920:(ow-iw)/2:(oh-ih)/2
```

| Component | Description |
|-----------|-------------|
| `1080` | Final canvas width |
| `1920` | Final canvas height |
| `(ow-iw)/2` | X padding (centers content) |
| `(oh-ih)/2` | Y padding (centers content) |

This adds black bars (letterboxing) if the scaled content doesn't fill the frame.

### Codec Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `-c:v` | `libx264` | H.264 video codec (universal playback support) |
| `-preset` | `fast` | Encoding speed preset (fast = 2x faster than medium) |
| `-crf` | `23` | Constant Rate Factor (quality): 0=lossless, 51=worst |
| `-c:a` | `aac` | AAC audio codec (required for MP4) |
| `-b:a` | `128k` | Audio bitrate: 128 kbps (good quality for voice) |
| `-movflags` | `+faststart` | Move metadata to start of file (enables streaming) |

### CRF Quality Guide

| CRF | Quality | Use Case |
|-----|---------|----------|
| 18 | Visually lossless | Archival |
| 20 | Excellent | High quality distribution |
| **23** | **Good** | **Social media (recommended)** |
| 26 | Acceptable | Low bandwidth |
| 28+ | Visible degradation | Not recommended |

---

## 3. Alternative: Clip with Burned-in Subtitles

If you want to add subtitles directly to the video:

```bash
ffmpeg -y -ss {START} -i input.mp4 -t {DURATION} \
  -vf "crop=...,scale=...,pad=...,subtitles=subtitle.srt:force_style='FontName=Arial,FontSize=24,PrimaryColour=&HFFFFFF&,OutlineColour=&H000000&,Outline=2,Shadow=0,MarginV=50'" \
  -c:v libx264 -preset fast -crf 23 \
  -c:a aac -b:a 128k \
  -movflags +faststart \
  output.mp4
```

### Subtitle Style Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `FontName` | `Arial` | Font family |
| `FontSize` | `24` | Font size in points |
| `PrimaryColour` | `&HFFFFFF&` | Text color (white) in BGR format |
| `OutlineColour` | `&H000000&` | Outline color (black) |
| `Outline` | `2` | Outline thickness |
| `Shadow` | `0` | Shadow depth |
| `MarginV` | `50` | Vertical margin from bottom |

---

## 4. Probe Video Information

Get video metadata for debugging:

```bash
# Get all streams info
ffprobe -v quiet -print_format json -show_streams input.mp4

# Get duration
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 input.mp4

# Get resolution
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 input.mp4
```

---

## 5. Common Resolution Mappings

| Source Aspect | Source Size | Crop Size | Final Size |
|---------------|-------------|-----------|------------|
| 16:9 | 1920×1080 | 608×1080 | 1080×1920 |
| 16:9 | 1280×720 | 405×720 | 1080×1920 |
| 4:3 | 1440×1080 | 608×1080 | 1080×1920 |
| 21:9 | 2560×1080 | 608×1080 | 1080×1920 |

---

## 6. Performance Optimization

### For Faster Processing

```bash
# Use hardware acceleration (if available)
ffmpeg ... -c:v h264_videotoolbox ...  # macOS
ffmpeg ... -c:v h264_nvenc ...         # NVIDIA GPU
ffmpeg ... -c:v h264_vaapi ...         # Intel/AMD on Linux

# Use faster preset (lower quality)
ffmpeg ... -preset ultrafast -crf 23 ...

# Reduce output resolution
ffmpeg ... -vf "...,scale=720:1280:..." ...
```

### For Better Quality

```bash
# Use slower preset
ffmpeg ... -preset slow -crf 20 ...

# Two-pass encoding
ffmpeg -y -i input.mp4 -c:v libx264 -preset medium -b:v 5000k -pass 1 -an -f null /dev/null
ffmpeg -y -i input.mp4 -c:v libx264 -preset medium -b:v 5000k -pass 2 -c:a aac -b:a 192k output.mp4
```

---

## 7. Troubleshooting Commands

### Check FFmpeg Capabilities

```bash
# Supported codecs
ffmpeg -codecs | grep -E "264|265|aac"

# Supported filters
ffmpeg -filters | grep -E "crop|scale|pad|subtitle"

# Hardware acceleration
ffmpeg -hwaccels
```

### Debug Encoding Issues

```bash
# Verbose output
ffmpeg -v verbose -i input.mp4 -c:v libx264 output.mp4

# Show what would happen without encoding
ffmpeg -i input.mp4 -vf "..." -c:v libx264 -f null /dev/null
```

