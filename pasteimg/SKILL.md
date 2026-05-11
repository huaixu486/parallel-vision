---
name: pasteimg
description: Paste screenshots or clipboard images into Claude Code on Windows using a configurable vision sidecar model. Use when the user invokes /pasteimg, wants to keep an expensive or preferred main model for reasoning, wants to reduce image token cost, or needs image content while the selected main model cannot accept image input. Saves the image to temp, uses a configurable low-cost/vision-capable model, and returns an ASCII-safe text description so the main model can continue.
---

# Paste Image

Use this skill for Windows clipboard image intake in Claude Code.

## Workflow

1. Run the bundled helper script:
   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\pasteimg\scripts\pasteimg.ps1" -Describe`
2. Treat `PASTEIMG_IMAGE_PATH` as diagnostic context only.
3. Treat text between `PASTEIMG_DESCRIPTION_START` and `PASTEIMG_DESCRIPTION_END` as the user's pasted image content.
4. Do not call `Read` on the image path for this workflow unless the current main model is known to support image input.
5. Continue answering with the currently selected main model after the description is returned.

## Configuration

The vision model is independent from the current main Claude Code model. There are two supported configuration modes:

1. Reuse the current Claude Code API settings and only change the vision model name.
2. Use a separate vision API with its own `apiFormat`, `baseUrl`, `authToken`, and model.

This is useful when the main model is expensive, text-only, or rejects direct image input. For example, a user can keep Opus, DeepSeek, Mimo Pro, or another coding model as the main model, while using Haiku, Mimo 2.5, or another lower-cost image-capable model to interpret screenshots. The helper spends image tokens only on the configured vision model and passes a text description back to the main model.

Resolution order:

1. Script argument: `-VisionModel "model-name"`
2. Environment variable: `PASTEIMG_VISION_MODEL`
3. Skill config file: `~/.claude/skills/pasteimg/config.json`
4. Claude settings env: `PASTEIMG_VISION_MODEL`
5. Claude settings env: `ANTHROPIC_DEFAULT_HAIKU_MODEL`
6. Claude settings env: `ANTHROPIC_MODEL`

The script reads API credentials from the current Claude Code settings by default:
`~/.claude/settings.json` `env.ANTHROPIC_BASE_URL` and `env.ANTHROPIC_AUTH_TOKEN`.

For portable installs, these can also be provided by environment variables:

- `PASTEIMG_ANTHROPIC_BASE_URL`
- `PASTEIMG_ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_BASE_URL`
- `ANTHROPIC_AUTH_TOKEN` or `ANTHROPIC_API_KEY`

Optional settings:

- `PASTEIMG_API_FORMAT` or `config.json` `apiFormat`: `anthropic` or `openai`
- `PASTEIMG_BASE_URL` or `config.json` `baseUrl`
- `PASTEIMG_AUTH_TOKEN` or `config.json` `authToken`
- `PASTEIMG_MAX_TOKENS` or `config.json` `maxTokens`
- `PASTEIMG_DESCRIPTION_PROMPT` or `config.json` `descriptionPrompt`
- `PASTEIMG_CONFIG` to point at another JSON config file
- `PASTEIMG_CLAUDE_SETTINGS` to point at another Claude settings file

## Behavior

- Saves clipboard bitmap data or image file drops to `%TEMP%\claude-clipboard-images`.
- Sends the saved image to the configured Anthropic-compatible `/v1/messages` API.
- Returns a text description that is safe for PowerShell/terminal output.
- Non-ASCII visible text may be emitted as JSON-style `\uXXXX` escapes; interpret those escapes as Unicode text.
- If no image is available, ask the user to copy a screenshot/image first and run `/pasteimg` again.

## Files

- Skill script: `~/.claude/skills/pasteimg/scripts/pasteimg.ps1`
- Optional config: `~/.claude/skills/pasteimg/config.json`
- Slash command launcher: `~/.claude/commands/pasteimg.md`
