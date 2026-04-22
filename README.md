# How to Build Outlook-Friendly HTML with Claude Code

Use Claude Code to generate HTML content you can copy from Chrome/Edge and paste into Outlook as a well-formatted email. Newsletters are one example — announcements, event invites, status updates, anything that needs to look clean in Outlook works the same way.

The rules that make HTML survive Outlook's rendering engine (inline styles, table layouts, base64 images, etc.) are encoded in `CLAUDE.md`, so Claude handles them for you.

## Quick start

The workflow is a conversation, not a build pipeline.

**1. Start Claude in this repo.** Claude reads `CLAUDE.md` automatically and follows the Outlook constraints.

**2. Describe what you want.** A few ways to kick off:

- From scratch: *"Create an announcement about the Q2 tooling rollout. Header image, three bullet points, a call-to-action link at the bottom."*
- From a draft: *"Here's my content as markdown — turn it into Outlook-friendly HTML."*
- From a prior example: *"Use `release/newsletter-WW09-2026.html` as a template. We'll walk through the sections I want to change."*

**3. Iterate in the browser.** Open the generated HTML in Chrome or Edge and tell Claude what to change in plain English. When words aren't enough, two escape hatches:

- **Screenshot** the part that looks wrong, paste it into the chat, and say *"change this."*
- **Point Claude at the page directly:** *"Use the chrome-devtools MCP to open the file and see what I see."* The MCP server is wired up in `.mcp.json`.

**4. Add images as needed.** Two paths:

- **Find one online** (PNG or SVG works well), save it under `output/`, and tell Claude where to embed it.
- **Generate one with AI:** *"Generate 3 images of a stylized compass pointing forward, blue tones on white."* Claude will run `scripts/ai_generate_image.py`. Review the outputs, iterate on the prompt, then tell Claude which one to embed and where.

**5. Ship it.** In Chrome/Edge: `Cmd+A` (or `Ctrl+A`), copy, paste into a new Outlook email. Send it to yourself first to verify it looks right, then send to the real list.

## Example opening prompts

```
Create an Outlook-friendly HTML announcement about the AIDE WW17 release.
Include a banner image placeholder, a one-paragraph intro from Steve Kamer,
three feature highlights with short descriptions, and a closing CTA link.
```

```
Use release/newsletter-WW09-2026.html as a template for this month's issue.
Keep the structure and styling; I'll tell you what content to swap in.
```

```
Generate 3 image options for a small square icon suggesting "security" —
shield containing a stylized microchip, blue tones on white, no text.
```

## Optional: the build script

`scripts/build_newsletter.sh` produces a self-contained `-base64.html` file with all images embedded as base64 data URIs. **You usually don't need it** — pasting from Chrome/Edge into Outlook handles images correctly on its own.

Reach for it when you want a portable artifact: archiving a finished version in `release/`, sharing the `.html` file directly, or sending from a client where the clipboard path doesn't work. Usage:

```bash
./scripts/build_newsletter.sh my-email.html
```

Requires macOS (uses `sips`). Windows equivalents are in the reference doc.

## Further reading

- **`CLAUDE.md`** — the rules Claude follows when generating HTML. Edit this if you want to change defaults (color palette, font stack, structural conventions).
- **`docs/outlook-html-reference.md`** — why Outlook is the way it is, the full HTML spec, image-optimization details, Windows/OS guidance, pre-send checklist, and troubleshooting.
- **`templates/newsletter-template.html`** — a starting skeleton with section building blocks.
- **`release/`** — finished past issues, useful as templates or examples.
