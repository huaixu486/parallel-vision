---
description: Paste and describe the current Windows clipboard image using the pasteimg skill
argument-hint: [optional note]
allowed-tools: Bash(powershell.exe:*)
---

Use the `pasteimg` skill. This slash command is only a thin launcher for the skill's bundled script.

!`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\pasteimg\scripts\pasteimg.ps1" -Describe`

Important:
- Do not call the Read tool on the returned image path.
- Treat the text between `PASTEIMG_DESCRIPTION_START` and `PASTEIMG_DESCRIPTION_END` as the user's pasted image content. Non-ASCII characters may be represented as JSON-style `\uXXXX` escapes; interpret those escapes as Unicode text.
- Keep using the currently selected main model after the description is returned.
- If the user supplied extra text after `/pasteimg`, use it as their request about the pasted image:

$ARGUMENTS

If the script reports that no image was found, tell the user to copy a screenshot/image first and run `/pasteimg` again.
