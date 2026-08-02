---
name: yt-summarizer
description: Use when the user provides a YouTube video link (youtube.com or youtu.be) and wants a well-structured summary of the video content. Fetches the video transcript and produces a structured summary.
---

# yt-summarizer

Generate a well-structured summary of a YouTube video from its transcript.

## Steps

1. **Extract the video ID**
   - From URLs like `https://www.youtube.com/watch?v=VIDEO_ID` or `https://youtu.be/VIDEO_ID`, parse the 11-character `VIDEO_ID`.
   - Strip tracking parameters (`si`, `t`, `list`, etc.) — only the video ID matters.

2. **Fetch the transcript** (English preferred, fall back to any available language)
   - Ensure `youtube-transcript-api` is installed:
     `pip3 install --quiet --break-system-packages --user youtube-transcript-api`
   - Run a Python script using `youtube_transcript_api`:
     ```python
     from youtube_transcript_api import YouTubeTranscriptApi
     api = YouTubeTranscriptApi()
     for t in api.list(VIDEO_ID):
         try:
             tr = api.fetch(VIDEO_ID, languages=['en'])
             print(" ".join(s.text for s in tr))
             break
         except Exception:
             continue
     ```
   - If the transcript fetch fails (e.g. captions disabled), fall back to `webfetch` on the video URL to at least capture the title and description, then tell the user the summary is limited.

3. **Produce the summary**
   - If transcript is available, generate a **well-structured summary** with:
     - A `**Summary:**` intro line of 1–2 sentences
     - Key sections using `###` headings that mirror the video's flow
     - Bullet points for facts, comparisons, or lists
     - A `**Bottom line / key takeaways:**` section with concise conclusions
   - Keep the summary faithful to the content — do not invent details not present in the transcript.
   - Use a numbered list if the video presents ranked/step-by-step content.

4. **Verify**
   - Ensure the summary covers the video's main arguments/topics, not just the intro.
   - If the user asked a specific question about the video, answer that question directly first, then provide the full summary.

## Notes

- You cannot watch the video — you summarize only from the transcript and any fetched metadata.
- If captions are unavailable, say so and provide whatever metadata you could retrieve.
