FROM n8nio/n8n:latest

# Switch to root to install packages
USER root

# Install FFmpeg, Python, pip, and bc
RUN apk add --no-cache \
    ffmpeg \
    python3 \
    py3-pip \
    bc \
    && pip3 install --break-system-packages yt-dlp

# Switch back to node user
USER node

# n8n will start automatically via the base image's entrypoint

