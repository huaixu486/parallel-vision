# Parallel Vision / 并行视觉

Use a separate, configurable vision model to understand screenshots in Claude Code, then pass the result back to your current main model as text.

Parallel Vision is useful when your main model is expensive, text-only, or simply not the model you want to spend image tokens on. Keep using Opus, DeepSeek, Mimo Pro, or any other main coding model for reasoning, while a cheaper vision-capable model handles screenshot recognition in parallel.

The installed Claude Code skill is named `pasteimg`, and the slash command is `/pasteimg`.

## Core Idea

Claude Code normally sends images to the currently selected model. That is not always ideal:

- The main model may reject image input on a third-party route.
- The main model may be expensive, and screenshots can consume a lot of tokens.
- A lower-tier model may be good enough for OCR, UI reading, terminal screenshots, and error messages.
- Different users may want different providers, such as DeepSeek, Opus/Haiku, Mimo, or another Anthropic-compatible route.

Parallel Vision splits the work:

1. `/pasteimg` saves the clipboard image to a temp file.
2. A configurable vision model reads the image and produces a text description.
3. The current main model receives that text and continues the conversation.

This gives you a practical "vision sidecar": use a low-cost image-capable model for seeing, and keep your preferred main model for thinking.

## Does This Replace Claude Code Image Reading?

No. Parallel Vision does not modify Claude Code's native `Read` tool or its built-in image handling.

It only changes the `/pasteimg` workflow:

- `/pasteimg` uses the configured vision sidecar model and returns text.
- Manual `Read` calls still use Claude Code's normal behavior.
- If your current main model supports image input, native `Read` can still work normally.
- If your current main model rejects image input, native `Read` may still fail, even though `/pasteimg` works through the sidecar model.
- Removing or not using this skill restores the ordinary Claude Code behavior; there is no global patch to undo.

## Install

From this repository root:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1
```

Restart Claude Code after installing.

To overwrite an existing install:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1 -Force
```

## Two Configuration Modes

Parallel Vision supports two ways to choose the vision sidecar.

### Option 1: Use Another Model On The Current Claude Code API

This is the default and the simplest setup. Parallel Vision reuses your current Claude Code API settings from `~/.claude/settings.json`, but sends screenshots to a different model name.

Use this when your provider exposes both your main model and a cheaper image-capable model on the same API route.

Example:

```json
{
  "visionModel": "your-low-cost-vision-model",
  "maxTokens": 2048
}
```

You can also set:

```powershell
$env:PASTEIMG_VISION_MODEL = "your-low-cost-vision-model"
```

### Option 2: Use A Separate Vision API

Use this when your screenshot model lives on a different provider, base URL, token, or protocol than your current Claude Code model.

Example for an Anthropic-compatible vision API:

```json
{
  "apiFormat": "anthropic",
  "visionModel": "your-vision-model",
  "baseUrl": "https://example.com/anthropic",
  "authToken": "your-token",
  "maxTokens": 2048
}
```

Example for an OpenAI-compatible vision API:

```json
{
  "apiFormat": "openai",
  "visionModel": "your-vision-model",
  "baseUrl": "https://example.com/v1",
  "authToken": "your-token",
  "maxTokens": 2048
}
```

Do not commit `config.json` if it contains a token. The included `.gitignore` excludes it.

## Config File

Copy the example config:

```powershell
Copy-Item ".\pasteimg\config.example.json" "$env:USERPROFILE\.claude\skills\pasteimg\config.json"
notepad "$env:USERPROFILE\.claude\skills\pasteimg\config.json"
```

Example:

```json
{
  "apiFormat": "anthropic",
  "visionModel": "your-low-cost-vision-model",
  "maxTokens": 2048,
  "baseUrl": "",
  "authToken": "",
  "descriptionPrompt": ""
}
```

If `baseUrl` or `authToken` are empty, Parallel Vision falls back to your current Claude Code API settings.

You can also use environment variables:

```powershell
$env:PASTEIMG_VISION_MODEL = "your-low-cost-vision-model"
$env:PASTEIMG_API_FORMAT = "anthropic"
$env:PASTEIMG_BASE_URL = "https://example.com/anthropic"
$env:PASTEIMG_AUTH_TOKEN = "your-token"
$env:PASTEIMG_MAX_TOKENS = "2048"
```

Examples of possible setups:

| Main model | Vision sidecar |
| --- | --- |
| Opus for coding | Haiku or another low-cost vision model |
| DeepSeek for reasoning | Any image-capable Anthropic-compatible model |
| Mimo Pro for code | Mimo 2.5 or another vision-enabled route |

The exact model names depend on your provider. The vision model must support image input on your API route.

## API Setting Resolution

Current Claude Code API settings are read from `~/.claude/settings.json` by default:

- `env.ANTHROPIC_BASE_URL`
- `env.ANTHROPIC_AUTH_TOKEN`

For a separate vision API, use config fields or environment variables:

- `apiFormat`: `anthropic` or `openai`
- `baseUrl`
- `authToken`
- `PASTEIMG_API_FORMAT`
- `PASTEIMG_BASE_URL`
- `PASTEIMG_AUTH_TOKEN`
- `PASTEIMG_ANTHROPIC_BASE_URL`
- `PASTEIMG_ANTHROPIC_AUTH_TOKEN`
- `PASTEIMG_OPENAI_BASE_URL`
- `PASTEIMG_OPENAI_API_KEY`
- `ANTHROPIC_BASE_URL`
- `ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_API_KEY`
- `OPENAI_BASE_URL`
- `OPENAI_API_KEY`

Vision model resolution order:

1. `-VisionModel`
2. `PASTEIMG_VISION_MODEL`
3. `pasteimg/config.json` `visionModel`
4. `~/.claude/settings.json` `env.PASTEIMG_VISION_MODEL`
5. `~/.claude/settings.json` `env.ANTHROPIC_DEFAULT_HAIKU_MODEL`
6. `~/.claude/settings.json` `env.ANTHROPIC_MODEL`

## Usage

Copy a screenshot or image, then run in Claude Code:

```text
/pasteimg describe this screenshot
```

The command returns:

```text
PASTEIMG_IMAGE_PATH: ...
PASTEIMG_VISION_MODEL: ...
PASTEIMG_DESCRIPTION_START
...
PASTEIMG_DESCRIPTION_END
```

The selected main model receives the text description and can continue the conversation without receiving image input directly.

## Test Without Clipboard

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\pasteimg\scripts\pasteimg.ps1" -Describe -ImagePath "C:\path\to\image.png"
```
