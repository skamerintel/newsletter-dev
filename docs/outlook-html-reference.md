# Outlook HTML Reference

Deep reference for the Outlook HTML workflow. The [README](../README.md) has the Quick Start — this doc explains *why* things are the way they are, covers image generation and optimization in detail, OS-specific setup, and troubleshooting.

The rules Claude follows when generating HTML live in [`../CLAUDE.md`](../CLAUDE.md). This doc is for humans who want to understand the constraints or debug when something doesn't render.

## Table of contents

1. [Why Outlook is the constraint](#why-outlook-is-the-constraint)
2. [Image generation](#image-generation)
3. [Image optimization and the build script](#image-optimization-and-the-build-script)
4. [OS-specific guidance](#os-specific-guidance)
5. [Pre-send checklist](#pre-send-checklist)
6. [Common pitfalls](#common-pitfalls)
7. [Troubleshooting](#troubleshooting)

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

Recipients often see a "Click here to download external images" banner if you reference images by URL. Base64-embedding sidesteps this — the images travel inside the HTML.

**What actually happens when you paste:** Outlook's composer parses your base64 `data:` URIs (or the image blobs on the clipboard when you copy from Chrome/Edge) and converts them to MIME-inline attachments (`cid:` references) in the sent message. The recipient sees inline images that Outlook has pre-approved because they came in the message itself. Don't be surprised when you inspect a sent message and see `cid:image001.jpg` instead of base64 — that's normal.

---

## Image generation

`scripts/ai_generate_image.py` is a Gemini wrapper (backed by Vertex AI) for generating section icons, banners, and stylized avatars.

### Credentials (one-time setup)

The script authenticates to Gemini via a GCP access token:

1. Go to **https://tokengen.aide.infra-host.com/experimental-gcp/**
2. Follow the instructions there to obtain and apply the token to your local environment.

Once authenticated, the script picks up credentials automatically. If a run fails with an auth/permission error, your token has likely expired — return to tokengen and refresh.

### Usage

```bash
uv run python scripts/ai_generate_image.py -p "PROMPT" -o output/filename.png -m flash -n 3
```

- `-m flash` vs `-m pro` — Flash is fast and cheap and has produced usable output for every section icon in the project to date. Reserve `pro` for cases where flash output is consistently unusable.
- `-n 3` — always generate 3 variants. Pick the best.
- `-i <reference-image>` — for stylized avatars ("like this but illustrated"). Supply a reference photo.

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

## Image optimization and the build script

`scripts/build_newsletter.sh` is optional. The copy-from-browser paste path carries images on the clipboard and Outlook inlines them automatically. The build script exists when you need a self-contained, portable `.html` file — for archiving, sharing, or sending from a client where the clipboard flow doesn't work.

### What the script does

For every image referenced in the HTML:

1. Resize (preserving aspect ratio, never upscale)
2. Convert PNG → JPEG (much smaller base64 output)
3. Base64-encode
4. Substitute into the HTML in place of the `src` path

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

The build script gets this right — but if you're optimizing an image by hand, remember.

### Size budget

Aim for individual images under **~330KB base64-embedded**. The AIDE banner sits near that ceiling. If you go higher on one image, compensate elsewhere. The overall HTML file should stay well under 2MB to avoid Exchange complaining.

### Filename → dimension inference

`build_newsletter.sh` picks the max dimension from the filename:
- Filename contains `banner` → 640px
- Otherwise → 200px

If you add a new image that should be banner-sized but doesn't have "banner" in its name, either rename it or modify the script.

---

## OS-specific guidance

The build script is **macOS-only** because it uses `sips` (an Apple built-in). The conversation + copy-paste workflow works identically on any OS.

### Windows: three options for the build script

**Option 1: WSL (recommended).** Install Windows Subsystem for Linux, then ImageMagick inside it, then run `build_newsletter.sh` unchanged after swapping `sips` for `magick`:

```powershell
wsl --install          # one-time, requires reboot
```
```bash
sudo apt install imagemagick
```

**Option 2: Native Windows with ImageMagick.** `winget install ImageMagick.ImageMagick`, then:

| macOS command | Windows equivalent |
|---|---|
| `sips -s format jpeg -s formatOptions 70 -Z 640 in.png --out out.jpg` | `magick in.png -resize 640x640^> -quality 70 out.jpg` |
| `base64 -i file.jpg` | PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("file.jpg"))` |

Note the `^>` — ImageMagick's "resize only if larger" flag, matching `sips -Z` behavior (never upscales).

**Option 3: Git Bash.** Git for Windows gives you Bash with `base64`, `sed`, `grep`, etc., but still no `sips` — pair it with ImageMagick for near-parity with the macOS flow.

### Clipboard shortcuts

- macOS: `Cmd+A` / `Cmd+C` / `Cmd+V`
- Windows: `Ctrl+A` / `Ctrl+C` / `Ctrl+V`

### Browser choice for copy-paste

- **macOS:** Safari and Chrome both work. Safari has slightly cleaner copy-to-Outlook behavior in practice.
- **Windows:** Chrome or Edge. Edge is pre-installed and works well.
- **Avoid Firefox** — its clipboard behavior has stripped inline styles in the past.

### Font rendering

The HTML specifies `'Segoe UI', Arial, sans-serif`. Segoe UI ships with Windows and Office. On macOS it silently falls back to a system sans-serif in the author's local preview — that's fine because recipients on Windows will see the real Segoe UI. Don't remove the fallback chain.

---

## Pre-send checklist

Before sending to the distribution list:

- [ ] Open the HTML in the browser. All images render (no broken icons)?
- [ ] Every `<img>` has a meaningful `alt` attribute?
- [ ] File size under 2MB (if using the base64 build)?
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

**Don't skip `alt` text.** Some fraction of recipients use screen readers or have images disabled. Alt text is their experience.

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

Almost always one of: a `<div>` used for layout, shorthand CSS, a missing inline style, or a CSS class reference. Inspect the offending section and move everything to inline styles on `<table>` elements.

### "Colors look wrong in dark mode"

Outlook Web and mobile force-invert some colors. Design for light mode and accept that dark mode recipients will see a slightly altered palette. If critical, add `<meta name="color-scheme" content="light only">` in `<head>` — but Outlook's support for this meta tag is inconsistent.

### "My base64 file is huge (>5MB)"

One or more images are under-optimized. Check the file sizes in `output/optimized/` — any single image over ~500KB is a candidate for more aggressive compression, higher `-Z` reduction, or conversion to JPEG if it's still PNG.
