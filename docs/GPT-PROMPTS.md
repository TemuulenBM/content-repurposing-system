# GPT Prompts Reference

This document contains all GPT prompts used in the workflow with explanations and customization options.

---

## 1. Key Moment Detection Prompt

**Node:** Detect Key Moments (GPT)  
**Model:** gpt-5.2-pro  
**Temperature:** 0.3 (deterministic)  
**Max Tokens:** 2000

### Full Prompt

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

### Variable Substitutions

| Variable | Source | Example |
|----------|--------|---------|
| `{{ platform }}` | Input JSON | "tiktok", "instagram", "youtube_shorts" |
| `{{ style }}` | Input JSON | "educational", "entertainment", "motivational" |
| `{{ fullText }}` | Whisper output | Full transcript text |
| `{{ transcript }}` | Whisper output | JSON array of timestamped segments |

### Why This Prompt Works

1. **Role Definition:** Establishes expertise context
2. **Clear Objective:** Specific platform targeting
3. **Content Context:** Style guides selection criteria
4. **Strict Rules:** Prevents edge cases
5. **Prioritization List:** Guides quality decisions
6. **Structured Output:** Ensures parseable response

### Customization Options

#### For Educational Content
Add to rules:
```
- Focus on "aha moments" and key takeaways
- Prioritize clear explanations of complex topics
- Select moments that provide immediate value
```

#### For Entertainment Content
Add to rules:
```
- Focus on punchlines and payoffs
- Prioritize unexpected twists or reactions
- Select moments with high emotional intensity
```

#### For Podcast Clips
Add to rules:
```
- Focus on complete thoughts and stories
- Prioritize moments with clear beginning/middle/end
- Select quotable statements
```

---

## 2. Caption Generation Prompt

**Node:** Generate Caption (GPT)  
**Model:** gpt-5.2  
**Temperature:** 0.7 (creative)  
**Max Tokens:** 500

### Full Prompt

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

### Variable Substitutions

| Variable | Source | Example |
|----------|--------|---------|
| `{{ platform }}` | Input JSON | "tiktok" |
| `{{ reason }}` | Moment detection | "Strong emotional revelation about failure" |
| `{{ hookPotential }}` | Moment detection | "I almost gave up that day..." |
| `{{ style }}` | Input JSON | "motivational" |
| `{{ fullText }}` | Whisper output | First 1500 characters for context |

### Example Outputs by Platform

#### TikTok
```json
{
  "hook": "Nobody's talking about this 👀",
  "caption": "This hit different. Had to share.",
  "hashtags": ["#fyp", "#viral", "#mindset", "#realtalk", "#growth"]
}
```

#### Instagram Reels
```json
{
  "hook": "Save this for when you need it 📌",
  "caption": "The advice I wish I had 5 years ago. Sometimes the best lessons come from the hardest moments.",
  "hashtags": ["#motivation", "#personalgrowth", "#lifelessons", "#mindsetshift", "#dailyinspiration"]
}
```

#### YouTube Shorts
```json
{
  "hook": "This changed how I think about success",
  "caption": "The truth nobody wants to tell you about making it.",
  "hashtags": ["#shorts", "#success", "#advice", "#entrepreneur", "#motivation"]
}
```

### Customization Options

#### Add Trending Sounds Reference
```
Also suggest a trending sound that would match this content vibe.
Add to output:
  "suggestedSound": "<sound name or style>"
```

#### Add CTA Variations
```
CREATE:
4. CTA: A call-to-action for the caption (follow, save, comment prompt)
```

#### Industry-Specific Hashtags
```
HASHTAG GUIDELINES:
- Always include 1 broad hashtag (#fyp, #viral)
- Include 2 niche hashtags for the industry
- Include 1 trending hashtag
- Include 1 branded hashtag if applicable
```

---

## 3. Alternative Prompts

### Viral Hook Generator

For generating multiple hook options:

```
You are a viral hook specialist. Generate 5 scroll-stopping hooks for this content.

Content Summary: {{ reason }}
Key Quote: {{ hookPotential }}

HOOK TYPES TO INCLUDE:
1. Curiosity gap (makes them want to know more)
2. Controversial take (makes them want to argue)
3. Emotional trigger (makes them feel something)
4. Direct value (tells them what they'll learn)
5. Pattern interrupt (unexpected/weird)

OUTPUT FORMAT (JSON):
{
  "hooks": [
    { "type": "curiosity", "text": "..." },
    { "type": "controversial", "text": "..." },
    { "type": "emotional", "text": "..." },
    { "type": "value", "text": "..." },
    { "type": "pattern_interrupt", "text": "..." }
  ],
  "recommended": "<index of best hook for this content>"
}
```

### Content Quality Scoring

For filtering clips before processing:

```
Rate this transcript segment for short-form video potential.

Segment: {{ segmentText }}
Start: {{ start }}
End: {{ end }}

SCORE (1-10) based on:
1. Hook Strength: Does it grab attention immediately?
2. Standalone Value: Does it make sense without context?
3. Emotional Impact: Does it evoke a reaction?
4. Shareability: Would someone share this?
5. Clip Length: Is it the right length (30-60s)?

OUTPUT FORMAT (JSON):
{
  "scores": {
    "hookStrength": <1-10>,
    "standaloneValue": <1-10>,
    "emotionalImpact": <1-10>,
    "shareability": <1-10>,
    "lengthAppropriate": <1-10>
  },
  "totalScore": <average>,
  "recommendation": "include" | "skip",
  "reason": "<brief explanation>"
}
```

---

## 4. Prompt Engineering Tips

### For Better JSON Output

1. **Explicit Formatting:**
   ```
   Return ONLY the JSON, no markdown code blocks, no explanations.
   ```

2. **Show Example:**
   ```
   Example output:
   {"hook": "Example text", "caption": "Example", "hashtags": ["#one"]}
   ```

3. **Validation Rules:**
   ```
   VALIDATION:
   - hook must be under 50 characters
   - caption must be under 150 characters
   - exactly 5 hashtags required
   ```

### For Consistent Quality

1. **Use Lower Temperature (0.2-0.4):**
   - More consistent outputs
   - Better for structured data

2. **Provide Negative Examples:**
   ```
   DO NOT:
   - Use generic hooks like "You won't believe..."
   - Include more than 5 hashtags
   - Use hashtags with spaces
   ```

3. **Chain of Thought:**
   ```
   First, analyze the content for the most engaging element.
   Then, craft a hook that highlights that element.
   Finally, structure the output as JSON.
   ```

### For Platform Authenticity

Include real platform trends:
```
CURRENT TIKTOK TRENDS TO CONSIDER:
- Storytimes format: "Storytime: how I..."
- POV format: "POV: you just realized..."
- Hot takes: "Unpopular opinion but..."
- Tutorials: "How to X in 30 seconds"
```

---

## 5. Cost Estimation

### Per Job Estimate (5 clips)

| API Call | Tokens | Cost (gpt-5.2) |
|----------|--------|---------------|
| Moment Detection | ~4000 | ~$0.02 |
| Caption Gen (x5) | ~500 each | ~$0.015 |
| **Total** | ~6500 | **~$0.035** |

### Monthly Cost (1000 jobs)
- GPT Costs: ~$35
- Whisper: ~$6/hour of audio × avg 15min = ~$1.50/job × 1000 = ~$1500
- **Total API costs: ~$1535/month**

---

## 6. Testing Prompts

Test with sample transcript:

```bash
curl https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "gpt-5.2-pro",
    "messages": [{"role": "user", "content": "YOUR_PROMPT_HERE"}],
    "temperature": 0.3,
    "max_tokens": 2000
  }'
```

