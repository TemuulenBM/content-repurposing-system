#!/bin/bash

# Check if all required dependencies are installed in the n8n container
# Usage: docker exec -it n8n-video-repurpose /bin/sh < scripts/check-dependencies.sh

echo "========================================"
echo "Dependency Check"
echo "========================================"
echo ""

# Check FFmpeg
echo -n "FFmpeg: "
if command -v ffmpeg &> /dev/null; then
  ffmpeg -version | head -n1
else
  echo "❌ NOT INSTALLED"
fi

# Check FFprobe
echo -n "FFprobe: "
if command -v ffprobe &> /dev/null; then
  ffprobe -version | head -n1
else
  echo "❌ NOT INSTALLED"
fi

# Check yt-dlp
echo -n "yt-dlp: "
if command -v yt-dlp &> /dev/null; then
  yt-dlp --version
else
  echo "❌ NOT INSTALLED"
fi

# Check bc (for calculations)
echo -n "bc: "
if command -v bc &> /dev/null; then
  echo "✅ Installed"
else
  echo "❌ NOT INSTALLED"
fi

# Check Python
echo -n "Python: "
if command -v python3 &> /dev/null; then
  python3 --version
else
  echo "❌ NOT INSTALLED"
fi

echo ""
echo "========================================"
echo "Disk Space"
echo "========================================"
df -h /data 2>/dev/null || echo "⚠️  /data directory not mounted"

echo ""
echo "========================================"
echo "Test Commands"
echo "========================================"
echo ""
echo "Run these to verify functionality:"
echo ""
echo "# Test yt-dlp"
echo "yt-dlp -F 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'"
echo ""
echo "# Test FFmpeg"
echo "ffmpeg -f lavfi -i nullsrc=s=1920x1080:d=1 -f null -"
echo ""

