# Workflow Testing Guide

Энэхүү гарын авлага нь Video Content Repurposing workflow-г хэрхэн туршиж, debug хийх талаар зааварчилна.

## 📋 Урьдчилсан нөхцөл

### 1. n8n ажиллаж байгаа эсэхийг шалгах

```bash
# Docker container статус шалгах
docker-compose ps

# n8n health check
curl http://localhost:5678/healthz
```

**Хүлээгдэх үр дүн**: `{"status":"ok"}`

### 2. Workflow import хийсэн эсэхийг шалгах

1. Browser дээрээ `http://localhost:5678` нээх
2. Login хийх (`.env` файл дахь `N8N_BASIC_AUTH_USER` болон `N8N_BASIC_AUTH_PASSWORD`)
3. **Workflows** цэс рүү орох
4. "Video Content Repurposing Pipeline v3" workflow олох
5. Workflow **Active** (идэвхтэй) байгаа эсэхийг шалгах (toggle switch нь ON байх ёстой)

### 3. Credentials тохируулсан эсэхийг шалгах

Workflow дээр дараах node-ууд credential шаарддаг:

| Node | Credential Type | Шалгах арга |
|------|----------------|-------------|
| **Transcribe (Whisper API)** | OpenAI API | Node дээр дарж, credential dropdown-оос сонгох |
| **Detect Key Moments (GPT)** | OpenAI API | Node дээр дарж, credential dropdown-оос сонгох |
| **Generate Caption (GPT)** | OpenAI API | Node дээр дарж, credential dropdown-оос сонгох |
| **Upload to R2** | AWS (Cloudflare R2) | Node дээр дарж, credential dropdown-оос сонгох |

**Credential үүсгэх**:
1. n8n UI дээр **Credentials** цэс рүү орох
2. **Add Credential** дарна
3. **OpenAI API** эсвэл **AWS** сонгоно
4. Шаардлагатай мэдээллийг оруулна:
   - **OpenAI API**: API Key (`sk-...`)
   - **AWS (R2)**: Access Key ID, Secret Access Key, Region (`auto`)

---

## 🧪 Тест хийх арга замууд

### Арга 1: Test Script ашиглах (Хамгийн хялбар)

```bash
# Basic test (default YouTube video)
./scripts/test-webhook.sh

# Custom video URL
./scripts/test-webhook.sh "https://www.youtube.com/watch?v=YOUR_VIDEO_ID"

# Full parameters
./scripts/test-webhook.sh \
  "https://www.youtube.com/watch?v=YOUR_VIDEO_ID" \
  "https://webhook.site/YOUR_UNIQUE_ID" \
  "tiktok" \
  "educational"
```

### Арга 2: cURL ашиглах

```bash
curl -X POST http://localhost:5678/webhook/repurpose-video \
  -H "Content-Type: application/json" \
  -d '{
    "jobId": "test-001",
    "videoUrl": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    "callbackUrl": "https://webhook.site/YOUR_UNIQUE_ID",
    "platform": "tiktok",
    "style": "educational"
  }'
```

### Арга 3: n8n UI дээрээс тест хийх

1. Workflow нээх
2. **Execute Workflow** товч дарна
3. **Webhook Trigger** node дээр дарж, **Test** дарна
4. JSON input оруулна:
```json
{
  "body": {
    "jobId": "test-001",
    "videoUrl": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    "callbackUrl": "https://webhook.site/YOUR_UNIQUE_ID",
    "platform": "tiktok",
    "style": "educational"
  }
}
```

---

## 📊 Workflow Execution-г хэрхэн хянах

### 1. n8n Executions харах

1. n8n UI дээр **Executions** цэс рүү орох
2. Хамгийн сүүлийн execution олох
3. Execution дээр дарж дэлгэрэнгүй мэдээлэл харах

### 2. Real-time Logs харах

```bash
# n8n container logs
docker-compose logs -f n8n

# Зөвхөн error logs
docker-compose logs n8n | grep -i error
```

### 3. Workflow доторх node-уудыг шалгах

1. Workflow нээх
2. Execution хийсний дараа node-ууд дээр **status indicator** харагдана:
   - 🟢 **Green**: Амжилттай
   - 🔴 **Red**: Алдаа гарсан
   - 🟡 **Yellow**: Ажиллаж байна
3. Node дээр дарж **output data** харах

---

## ✅ Хүлээгдэх үр дүн

### Амжилттай execution-ийн дараалал:

1. **Webhook Trigger** ✅
   - Input validation амжилттай
   - Response: `{"received": true}`

2. **Download Video** ✅
   - Video татагдсан
   - Output: `./data/{jobId}/input.mp4` файл үүссэн

3. **Extract Audio** ✅
   - Audio extract хийгдсэн
   - Output: `./data/{jobId}/audio.wav` файл үүссэн

4. **Transcribe (Whisper API)** ✅
   - Transcription амжилттай
   - Output: JSON transcript segments

5. **Detect Key Moments (GPT)** ✅
   - 5 moments detect хийгдсэн
   - Output: Array of moments with start/end times

6. **Loop Over Moments** ✅
   - 5 удаа ажиллана (moment бүрт)
   - Output: 5 clips үүссэн (`clip_1.mp4`, `clip_2.mp4`, ...)

7. **Generate Caption (GPT)** ✅
   - Caption generate хийгдсэн
   - Output: hook, caption, hashtags

8. **Upload to R2** ✅
   - Clip R2-д upload хийгдсэн
   - Output: Public URL

9. **Callback to Backend** ✅
   - Callback URL руу POST request илгээгдсэн
   - Output: Success response

---

## 🐛 Алдаа засах (Troubleshooting)

### Алдаа 1: "Webhook not found" эсвэл 404

**Шалтгаан**: Workflow active биш эсвэл webhook path буруу

**Шийдэл**:
1. Workflow **Active** байгаа эсэхийг шалгах
2. Webhook path шалгах: `/webhook/repurpose-video`
3. n8n-г restart хийх: `docker-compose restart n8n`

### Алдаа 2: "Invalid credentials" эсвэл Authentication error

**Шалтгаан**: OpenAI эсвэл R2 credential буруу

**Шийдэл**:
1. Credential-ууд зөв тохируулсан эсэхийг шалгах
2. API key-ууд хүчинтэй эсэхийг шалгах
3. `.env` файл дахь environment variables шалгах

### Алдаа 3: "Video download failed"

**Шалтгаан**: yt-dlp video татаж чадахгүй байна

**Шийдэл**:
1. Video URL хүчинтэй эсэхийг шалгах
2. Video public байгаа эсэхийг шалгах (private video-г татаж чадахгүй)
3. yt-dlp update хийх: `docker-compose exec n8n pip3 install --upgrade yt-dlp`

### Алдаа 4: "FFmpeg command failed"

**Шалтгаан**: FFmpeg command буруу эсвэл file олдохгүй байна

**Шийдэл**:
1. Input file байгаа эсэхийг шалгах: `docker-compose exec n8n ls -la /data/{jobId}/`
2. FFmpeg install хийгдсэн эсэхийг шалгах: `docker-compose exec n8n ffmpeg -version`
3. Container-д file permissions шалгах

### Алдаа 5: "OpenAI API rate limit exceeded"

**Шалтгаан**: API rate limit хэтэрсэн

**Шийдэл**:
1. Хэсэг хугацааны дараа дахин оролдох
2. OpenAI dashboard дээр rate limit шалгах
3. Retry logic нэмэх (workflow дээр)

### Алдаа 6: "R2 upload failed"

**Шалтгаан**: Cloudflare R2 credential эсвэл bucket name буруу

**Шийдэл**:
1. R2 credential зөв эсэхийг шалгах
2. Bucket name зөв эсэхийг шалгах (`.env` файл дахь `R2_BUCKET_NAME`)
3. R2 bucket public access зөв тохируулсан эсэхийг шалгах

---

## 📝 Test Cases

### Test Case 1: Basic Test (Short Video)

```bash
./scripts/test-webhook.sh \
  "https://www.youtube.com/watch?v=jNQXAC9IVRw" \
  "https://webhook.site/test-001" \
  "tiktok" \
  "entertainment"
```

**Хүлээгдэх үр дүн**: 5 clips үүсч, callback URL руу POST request илгээгдэнэ

### Test Case 2: Educational Content

```bash
./scripts/test-webhook.sh \
  "https://www.youtube.com/watch?v=YOUR_EDUCATIONAL_VIDEO" \
  "https://webhook.site/test-002" \
  "instagram" \
  "educational"
```

**Хүлээгдэх үр дүн**: Educational tone-той captions үүснэ

### Test Case 3: Long Video (30+ minutes)

```bash
./scripts/test-webhook.sh \
  "https://www.youtube.com/watch?v=YOUR_LONG_VIDEO" \
  "https://webhook.site/test-003" \
  "youtube_shorts" \
  "motivational"
```

**Хүлээгдэх үр дүн**: Workflow илүү удаан ажиллана (5-10 минут), гэхдээ амжилттай дуусна

---

## 🔍 Debug Tips

### 1. Node Output Data харах

Workflow execution хийсний дараа node бүр дээр дарж **output data** харах:
- Input data зөв ирсэн эсэх
- Output data хүлээгдэхүйц байгаа эсэх
- Error messages байгаа эсэх

### 2. Container дотор file-уудыг шалгах

```bash
# Job directory харах
docker-compose exec n8n ls -la /data/

# Тодорхой job-ийн файлууд харах
docker-compose exec n8n ls -la /data/{jobId}/

# Video file байгаа эсэхийг шалгах
docker-compose exec n8n file /data/{jobId}/input.mp4

# Audio file байгаа эсэхийг шалгах
docker-compose exec n8n file /data/{jobId}/audio.wav
```

### 3. Environment Variables шалгах

```bash
# Container доторх environment variables харах
docker-compose exec n8n env | grep -E "(OPENAI|R2|N8N)"
```

### 4. Network Issues шалгах

```bash
# OpenAI API-д хандах боломжтой эсэхийг шалгах
docker-compose exec n8n curl -I https://api.openai.com/v1/models

# Cloudflare R2 endpoint-д хандах боломжтой эсэхийг шалгах
docker-compose exec n8n curl -I https://{account_id}.r2.cloudflarestorage.com
```

---

## 📞 Тусламж авах

Хэрэв асуудал үргэлжилсээр байвал:

1. **n8n Community Forum**: https://community.n8n.io/
2. **GitHub Issues**: Workflow JSON файл болон error logs-ийг хамт илгээх
3. **Logs харах**: `docker-compose logs n8n` командыг ашиглах

---

## ✅ Testing Checklist

Workflow-г production-д deploy хийхээс өмнө дараах зүйлсийг шалгах:

- [ ] n8n container ажиллаж байна
- [ ] Workflow import хийгдсэн
- [ ] Workflow active байна
- [ ] Бүх credentials тохируулсан
- [ ] Test webhook амжилттай ажиллаж байна
- [ ] Video download амжилттай
- [ ] Audio extraction амжилттай
- [ ] Transcription амжилттай
- [ ] Key moments detection амжилттай
- [ ] Clips generation амжилттай
- [ ] Caption generation амжилттай
- [ ] R2 upload амжилттай
- [ ] Callback амжилттай
- [ ] Error handling зөв ажиллаж байна
- [ ] Long videos-д зөв ажиллаж байна (30+ минут)

---

**Амжилт хүсье! 🚀**

