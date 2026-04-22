# How to Build Outlook-Friendly HTML Newsletters

This is the human-facing guide. It explains *why* the workflow is the way it is, the moving parts, and the gotchas that cost time when you hit them for the first time. The rules the agent follows live in `CLAUDE.md`.

## Table of contents

1. [Why Outlook is the constraint](#why-outlook-is-the-constraint)
2. [End-to-end workflow](#end-to-end-workflow)
3. [Image generation](#image-generation)
4. [Image optimization](#image-optimization)
5. [OS-specific guidance](#os-specific-guidance)
6. [Pre-send checklist](#pre-send-checklist)
7. [Common pitfalls](#common-pitfalls)
8. [Troubleshooting](#troubleshooting)

---

## Why Outlook is the constraint

Outlook's HTML rendering lags behind modern browsers, and behavior varies across versions (Outlook 16.x on Mac, current Outlook desktop on Windows, Outlook Web, mobile). To get consistent rendering across all of them, aim for the lowest common denominator:

- Flexbox, CSS grid, floats — unreliable. Use `<table>` for layout.
- CSS classes and `<style>` blocks — frequently stripped. Inline every style.
- External `<img src="https://...">` — often blocked. Recipient sees a "download external images" banner, or nothing.
- Shorthand CSS (`margin: 10px 20px`) — may be dropped. Use `margin-top`, `margin-right`, etc.
- Background images, web fonts — inconsistent. Avoid.
- Dark mode — Outlook Web and mobile force-invert some colors. Design for light backgrounds.

### Why base64-embedding images matters

Recipients often see a "Click here to download external images" banner if you reference images by URL. For a newsletter going to 1000 people, that's 1000 people who might never see your images. Base64-embedding sidesteps this — the images travel inside the HTML.

**What actually happens when you paste:** Outlook's composer parses your base64 `data:` URIs and converts them to MIME-inline attachments (`cid:` references) in the sent message. The recipient sees inline images that Outlook has pre-approved because they came in the message itself. Don't be surprised when you inspect a sent message and see `cid:image001.jpg` instead of base64 — that's normal.

---

## End-to-end workflow

1. **Write** — copy `templates/newsletter-template.html` to `newsletter-WWXX-YEAR.html`, fill in content, reference local image paths.
2. **Generate any new images** — see [Image generation](#image-generation).
3. **Build** — run `./scripts/build_newsletter.sh newsletter-WWXX-YEAR.html`. This optimizes images and produces `newsletter-WWXX-YEAR-base64.html`.
4. **Preview** — open the base64 file in Chrome or Edge. Confirm images render, layout looks right.
5. **Test-send to yourself** — Cmd+A / Ctrl+A, Cmd+C / Ctrl+C, paste into an Outlook draft, send to your own address.
6. **View the test** on your Outlook desktop client, then on mobile and web if available.
7. **Send to distribution list.**

### Browser choice for copy-paste

- **macOS:** Safari and Chrome both work. Safari has slightly cleaner copy-to-Outlook behavior in practice.
- **Windows:** Chrome or Edge. Edge is pre-installed and works well.
- **Avoid Firefox** — its clipboard behavior has stripped inline styles in the past.

---

## Image generation

The project uses `scripts/ai_generate_image.py` (a Gemini wrapper, backed by Vertex AI) to generate section icons and banners.

### Credentials (one-time setup)

The script authenticates to Gemini via a GCP access token. To get one:

1. Go to **https://tokengen.aide.infra-host.com/experimental-gcp/**
2. Follow the instructions there to obtain and apply the token to your local environment.

Once your environment is authenticated, the script picks up credentials automatically. If a run fails with an auth/permission error, your token has likely expired — return to tokengen and refresh.

### Usage

```bash
uv run python scripts/ai_generate_image.py -p "PROMPT" -o output/filename.png -m flash -n 3
```

- `-m flash` vs `-m pro` — Flash is fast and cheap and has produced usable output for every section icon in the project to date. Reserve `pro` for cases where flash output is consistently unusable.
- `-n 3` — always generate 3 variants. Pick the best.
- `-i <reference-image>` — for stylized avatars / "like this but illustrated." Supply a reference photo.

### Prompt patterns that work

**Section icons (100px square):**
> "A small square icon illustration of **[SUBJECT]**, blue tones on white background, clean flat design, professional, suggesting **[SEMANTIC HINT]**, no text"

Examples that produced good results:
- *"...of a glowing blue key turning in a lock..."* (Get Started)
- *"...of a shield containing a stylized microchip..."* (Security)
- *"...of a stylized compass with the needle pointing forward and motion lines..."* (What's Next)
- *"...of overlapping speech bubbles with glowing connection lines..."* (Impact Stories)

**Wide banner:**
> "Abstract wide banner illustration, flowing streams of light blue and white data particles converging and accelerating from left to right, dark navy to white gradient background, minimal and clean, no text, professional tech aesthetic"

**Stylized avatar (requires `-i photo.jpg`):**
> "Create a professional stylized avatar portrait based on this photo. Clean modern illustration style. Keep the likeness and key features. 250x250 pixels, square format, subtle blue tones, white/light background."

### When a generation misses

Add **negative constraints explicitly.** The models don't always infer them:
- `"no text"` — almost always needed; models love to add captions.
- `"no borders, no outlines around the image"` — for icons that keep gaining unwanted frames.
- `"not cartoonish, not childish"` — when output drifts toward clipart.

For portraits, add explicit demographic/wardrobe details: *"brown hair mixed with grey (not fully grey), friendly slight smile, casual polo shirt (no suit/blazer)"*. Vague prompts produce generic output.

---

## Image optimization

The build script handles this automatically. This section explains what it's doing and the gotchas worth knowing.

### The pipeline

Every image referenced in the HTML gets:

1. Resized (preserving aspect ratio, never upscaled)
2. Converted PNG → JPEG (much smaller base64 output)
3. Base64-encoded
4. Substituted into the HTML in place of the `src` path

### Dimensions and quality

| Role | Display size | Max dimension | JPEG quality | Notes |
|---|---|---|---|---|
| Banner | 640px wide | `-Z 640` | 70 | Decorative only. No small text. |
| Section icon | 100px | `-Z 200` | 70 | 2x for retina displays. |
| Diagram / screenshot with text | 640px | `-Z 640` | **85-95, or PNG** | Quality 70 smudges small text illegibly. |

### The `sips` gotcha (macOS)

**If you run `sips` without `-s formatOptions`, it defaults to a very low JPEG quality and produces near-blank gray images.** Always include the quality flag explicitly:

```bash
sips -s format jpeg -s formatOptions 70 -Z 640 input.png --out output.jpg
```

This bit us once and cost an hour of "why does the newsletter look broken?" The build script gets this right — but if you're optimizing an image by hand, remember.

### Size budget

Aim for individual images under **~330KB base64-embedded**. That's the informal ceiling we've been treating as acceptable (the AIDE banner sits near it). If you go higher on one image, compensate elsewhere. The overall HTML file should stay well under 2MB to avoid Exchange complaining.

### Filename → dimension inference

`build_newsletter.sh` picks the max dimension from the filename:
- Filename contains `banner` → 640px
- Otherwise → 200px

If you add a new image that should be banner-sized but doesn't have "banner" in its name, either rename it or modify the script.

---

## OS-specific guidance

The build script and optimization tooling are currently **macOS-only** because they use `sips` (an Apple built-in). If you're on Windows, you have three options:

### Option 1: WSL (recommended)

Install Windows Subsystem for Linux, then ImageMagick inside it, then run the existing `build_newsletter.sh` unchanged:

```powershell
wsl --install          # one-time, requires reboot
```

Inside WSL:
```bash
sudo apt install imagemagick
```

You'll need to swap `sips` for `magick` in `build_newsletter.sh`, or keep a parallel WSL-specific build script. This is the lowest-friction path if you're comfortable with Linux tools.

### Option 2: Native Windows with ImageMagick

Install ImageMagick on Windows (`winget install ImageMagick.ImageMagick`), then use these replacements:

| macOS command | Windows equivalent |
|---|---|
| `sips -s format jpeg -s formatOptions 70 -Z 640 in.png --out out.jpg` | `magick in.png -resize 640x640^> -quality 70 out.jpg` |
| `base64 -i file.jpg` | PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("file.jpg"))` |

**Note the `^>`** — ImageMagick's "resize only if larger" flag, matching `sips -Z` behavior (never upscales).

Porting `build_newsletter.sh` to PowerShell is doable but roughly doubles maintenance. WSL is cleaner.

### Option 3: Git Bash

If you install Git for Windows, you get a Bash shell with `base64`, `sed`, `grep`, etc. — but still no `sips`. You'll still need ImageMagick. Git Bash + ImageMagick gets you close to parity with the macOS flow.

### Clipboard shortcuts

- macOS: `Cmd+A` / `Cmd+C` / `Cmd+V`
- Windows: `Ctrl+A` / `Ctrl+C` / `Ctrl+V`

### Font rendering

The HTML specifies `'Segoe UI', Arial, sans-serif`. Segoe UI ships with Windows and Office. On macOS it silently falls back to a system sans-serif in the author's local preview — but that's fine because **recipients on Windows will see the real Segoe UI** and that's what matters. Don't remove the fallback chain.

---

## Pre-send checklist

Before sending to the distribution list:

- [ ] Open the `-base64.html` file in the browser. All images render (no broken icons)?
- [ ] Every `<img>` has a meaningful `alt` attribute?
- [ ] File size under 2MB?
- [ ] Cmd/Ctrl+A, copy, paste into Outlook **draft**. Send to yourself.
- [ ] View the test in your Outlook desktop client — layout holds?
- [ ] View on Outlook mobile (iOS or Android) — readable at narrow width?
- [ ] View in dark mode (Outlook Web or mobile) — colors still legible?
- [ ] Links work? Click each one.
- [ ] Images appear inline, not as attachments at the bottom?
- [ ] No "download external images" banner at the top?
- [ ] Typography looks right — smart quotes, em-dashes, no raw `"` or `--`?

---

## Common pitfalls

**Don't use `<div>` for layout.** Use `<table role="presentation">`. Divs render inconsistently across Outlook versions.

**Don't use shorthand CSS.** Outlook may drop `margin: 10px 20px`. Expand to `margin-top: 10px; margin-right: 20px; ...`.

**Don't use background images.** They work in most modern clients but are unreliable in Outlook. Use a colored background and place the image as an `<img>`.

**Don't use web fonts.** `@font-face`, Google Fonts, etc. won't load. Stick to Segoe UI with Arial fallback.

**Don't use CSS classes or `<style>` blocks.** Everything inline. The one exception is MSO conditional blocks:

```html
<!--[if mso]>
<style type="text/css">
  table { border-collapse: collapse; }
</style>
<![endif]-->
```

**Don't forget `role="presentation"`** on layout tables. Without it, screen readers announce the table structure as data, which is noise.

**Don't skip `alt` text.** For a 1000-person distribution, some fraction use screen readers or have images disabled. Alt text is their experience.

**Don't reword testimonials.** Trim with ellipses if needed, but never paraphrase. Contributors trust you with their words.

---

## Troubleshooting

### "My images look gray/blank after optimization"

You're running `sips` without `-s formatOptions 70`. Add the flag.

### "Small text in my diagram is illegible after optimization"

JPEG quality 70 destroys small text. Either bump quality to 85-95, or keep the diagram as PNG (larger file, but legible).

### "Outlook shows 'Download external images' banner"

An `<img>` somewhere still has a URL `src` instead of a base64 `data:` URI. Re-run the build script, or search the HTML for `src="http`.

### "Images arrive as attachments, not inline"

Some Outlook versions handle `data:` URI paste differently. If the desktop client puts images at the bottom as attachments, try pasting from a different browser, or compose from Outlook Web as a fallback.

### "Layout looks fine in my browser, broken in Outlook"

Almost always because of one of: a `<div>` used for layout, shorthand CSS, a missing inline style, or a CSS class reference. Inspect the offending section and move everything to inline styles on `<table>` elements.

### "Colors look wrong in dark mode"

Outlook Web and mobile force-invert some colors. Design for light mode and accept that dark mode recipients will see a slightly altered palette. If critical, add `<meta name="color-scheme" content="light only">` in `<head>` — but Outlook's support for this meta tag is inconsistent.

### "My base64 file is huge (>5MB)"

One or more images are under-optimized. Check the file sizes in `output/optimized/` — any single image over ~500KB is a candidate for more aggressive compression, higher `-Z` reduction, or conversion to JPEG if it's still PNG.

---

## Further references

- `templates/newsletter-template.html` — the starting skeleton with section building blocks.
- `scripts/build_newsletter.sh` — the optimization + embedding pipeline.
- `scripts/ai_generate_image.py` — the Gemini image-generation wrapper.
- `release/` — final approved versions of past issues, useful as examples.
