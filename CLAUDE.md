# AIDE Newsletter Project

Monthly HTML newsletter for the AIDE (AI for Dev/Ops Efficiency) initiative at Intel. Distributed via Outlook email to ~1000 people.

Author: Steve Kamer, AI Evangelist.

For workflow background, prompt patterns, OS-specific guidance, and troubleshooting, see **README.md**. This file contains only the rules the agent must follow.

## Delivery model

HTML is opened in a browser, selected (Cmd+A / Ctrl+A), copied, and pasted into Outlook compose. All HTML must survive Word's rendering engine (classic Outlook).

## Hard rules — Outlook HTML

- **Table-based layout only** — no flexbox, grid, floats, or `<div>` layout.
- **All styles inline** — no `<style>` blocks except MSO conditionals.
- **Base64-embed all images** as `data:image/jpeg;base64,...` — no external `src` URLs. Outlook blocks external images by default.
- **Every `<img>` needs a meaningful `alt` attribute.**
- **Max content width 640px.** Use `<table role="presentation">` for all layout tables.
- **No CSS shorthand** — use `margin-top`, `margin-right`, etc. Outlook drops shorthand.
- **No background images, no web fonts, no CSS classes.**
- **Font stack:** `'Segoe UI', Arial, sans-serif`.
- **Typography as HTML entities:** `&ldquo;` `&rdquo;` `&mdash;` `&hellip;` `&bull;`.
- **Light background only** — white (`#ffffff`) card on light gray (`#f4f5f7`) page.

## Color palette

| Color | Hex | Usage |
|-------|-----|-------|
| Intel Blue | #0068b5 | Primary accent, headers, links, tier 1 borders, dividers |
| Dark Navy | #0f172a | Header background (below banner) |
| Body Text | #374151 | Paragraph text |
| Dark Text | #111827 | Bold/emphasis text |
| Gray | #6b7280 | Tier 2 borders, secondary labels |
| Light Gray | #9ca3af | Tier 3 labels, footer text |
| Lighter Gray | #d1d5db | Tier 3 borders |
| Stats BG | #f0f7ff | Stats card background |
| Page BG | #f4f5f7 | Outer background |
| Card BG | #ffffff | Main content background |

## Newsletter structure

1. Banner (640px-wide AIDE banner image)
2. Header — "AIDE Newsletter" + work week (e.g., "WW11 2026")
3. Intro/Mission + Steve Kamer sign-off
4. Stats — three cards
5. Content sections — blue divider, 100px icon + header, body
6. Footer — "AIDE Newsletter | WW## YEAR"

## Reusable section icons

Sources in `output/newsletter_*.png`, optimized copies in `output/optimized/`.

| Image | Section |
|-------|---------|
| newsletter_banner.png | Header |
| newsletter_testimonials.png | Impact Stories |
| newsletter_getstarted.png | Get Started |
| newsletter_security.png | Security & Compliance |
| newsletter_whatsnext.png | What's Next |

## Commands

**Generate an image:**
```bash
uv run python scripts/ai_generate_image.py -p "PROMPT" -o output/filename.png -m flash -n 3
```
Default to `-m flash -n 3`. Use `-m pro` only if flash output is unusable. Requires GCP credentials — see README.md.

**Build for distribution:**
```bash
./scripts/build_newsletter.sh newsletter-WWXX-YEAR.html
```
Produces `newsletter-WWXX-YEAR-base64.html` — self-contained, ready to paste into Outlook.

## Image optimization rules

The build script handles this via macOS `sips`. If invoking manually:

- **Always pass `-s formatOptions 70`** — `sips` without this flag produces near-blank images.
- **Banner** (640px display): `-Z 640`, quality 70.
- **Section icons** (100px display): `-Z 200` (2x retina), quality 70.
- **Diagrams/screenshots with text:** quality 85-95, or keep as PNG. Quality 70 destroys small text.
- **Per-image size budget:** target under ~330KB base64-embedded.

The build script infers dimension from filename: `banner` in the name → 640px, else 200px. Rename files accordingly.

## Key links

| Resource | URL |
|----------|-----|
| Tokengen | https://tokengen.aide.infra-host.com |
| AI University | https://aiuniversity.aide.infra-host.com/ |
| ITS Security Statement | https://wiki.ith.intel.com/spaces/AIDE/pages/4615872526/Statement+on+Claude+Code+Usage+for+ITS+Data |
| Support Email | ade-aide-support@intel.com |

## Intel conventions

- Dates: **work week** format, `WW01`-`WW52` + year (e.g., "WW11 2026").
- **ITS** = Intel Top Secret (data classification).
- **BKMs** = Best Known Methods.
- AI tools approved for ITS data at department level.

## Testimonial rules

- **Never reword testimonials.** Use original language verbatim.
- Ellipses (`&hellip;`) may be used to trim context only.
- Sort by impact: quantified results first, qualitative second, shorter/vaguer last.
- Border color indicates tier: blue `#0068b5` (tier 1), gray `#6b7280` (tier 2), light gray `#d1d5db` (tier 3).

## File organization

```
newsletter-dev/
├── CLAUDE.md                    # Agent rules (this file)
├── README.md                    # Human-facing workflow & best practices
├── templates/
│   └── newsletter-template.html
├── scripts/
│   ├── build_newsletter.sh      # Image optimization + base64 embed
│   └── ai_generate_image.py     # Gemini image generation
├── output/
│   ├── newsletter_*.png         # Source images
│   └── optimized/               # Generated JPEGs
├── release/                     # Final approved versions
└── [issue files]
```
