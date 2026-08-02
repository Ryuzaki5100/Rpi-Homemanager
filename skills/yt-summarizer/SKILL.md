---
name: yt-summarizer
description: Use when the user provides a YouTube video link (youtube.com or youtu.be) and wants a well-structured summary of the video content. Fetches the video transcript, produces a structured summary, and offers to export it as a markdown or EPUB file (or print it only).
---

# yt-summarizer

Generate a well-structured summary of a YouTube video from its transcript, then ask the user how they want it delivered: printed, saved as a markdown file, or exported as an EPUB with well-organized chapters/sections.

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

4. **Ask for the output format**
   - After producing the summary, ask the user which output they want:
     - **Print only** — output the summary in the chat, write no file
     - **Markdown file** — save the summary as a `.md` file
     - **EPUB file** — export the summary as an `.epub` with chapters/sections organized to match the video's content flow
   - If the user has already stated a preference, skip the prompt and honor it.

5. **Export the summary**
   - **Markdown:** write the summary to `~/yt-summaries/<sanitized-video-title>.md` (or a path the user specifies), creating the directory if needed. Sanitize the title to lowercase kebab-case (letters, digits, hyphens).
   - **EPUB:** first write the markdown (as above), then convert with `pandoc` (already available on the system):
     ```
     pandoc ~/yt-summaries/<sanitized-video-title>.md -o ~/yt-summaries/<sanitized-video-title>.epub \
       --metadata title="<Video title>" \
       --metadata author="yt-summarizer" \
       --toc --toc-depth=2
     ```
     - The summary's `###` section headings become the EPUB's chapters/table of contents, so keep them meaningful and mirroring the video's flow.
     - If the video has clearly distinct parts (e.g. tutorial chapters, interviews, talks), group related sections under top-level chapter headings so the EPUB reads like a book.
     - Confirm the `.epub` was created and report its path to the user.
   - For **print only**, just output the summary in the chat.

6. **Verify**
   - Ensure the summary covers the video's main arguments/topics, not just the intro.
   - If the user asked a specific question about the video, answer that question directly first, then provide the full summary.
   - If exporting to a file, confirm the file exists and, for EPUB, that `pandoc` ran successfully.

## Notes

- You cannot watch the video — you summarize only from the transcript and any fetched metadata.
- If captions are unavailable, say so and provide whatever metadata you could retrieve; the output options still apply, but the exported content will be limited.
- `pandoc` handles EPUB export — no extra packages are required.
