param(
    [switch]$Describe,
    [string]$VisionModel,
    [string]$ImagePath,
    [string]$BaseUrl,
    [string]$AuthToken,
    [int]$MaxTokens = 0,
    [string]$SettingsPath,
    [string]$ConfigPath,
    [switch]$NoEscape
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$skillRoot = Split-Path -Parent $PSScriptRoot
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) 'claude-clipboard-images'
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
$logPath = Join-Path ([System.IO.Path]::GetTempPath()) 'claude-pasteimg.log'

function Test-ImagePath {
    param([string]$Path)
    $ext = [System.IO.Path]::GetExtension($Path)
    return @('.png', '.jpg', '.jpeg', '.webp', '.bmp', '.gif') -contains $ext.ToLowerInvariant()
}

function Get-MediaType {
    param([string]$Path)
    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.jpg'  { 'image/jpeg'; break }
        '.jpeg' { 'image/jpeg'; break }
        '.webp' { 'image/webp'; break }
        '.gif'  { 'image/gif'; break }
        default { 'image/png'; break }
    }
}

function Convert-ToPngIfNeeded {
    param([string]$Path)
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($ext -ne '.bmp') { return $Path }

    $outPath = Join-Path $tempDir ("clipboard_{0}.png" -f (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
    $img = [System.Drawing.Image]::FromFile($Path)
    try {
        $img.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $img.Dispose()
    }
    return $outPath
}

function Save-ClipboardImage {
    $data = [System.Windows.Forms.Clipboard]::GetDataObject()
    $formats = @()
    if ($null -ne $data) {
        $formats = @($data.GetFormats())
    }
    "$(Get-Date -Format o) formats=$($formats -join ', ')" | Add-Content -Path $logPath -Encoding UTF8

    if ($null -ne $data -and $data.GetDataPresent('PNG')) {
        $png = $data.GetData('PNG')
        $path = Join-Path $tempDir ("clipboard_{0}.png" -f (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))

        if ($png -is [System.IO.Stream]) {
            $file = [System.IO.File]::Open($path, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
            try {
                $png.Position = 0
                $png.CopyTo($file)
            }
            finally {
                $file.Dispose()
            }
            return $path
        }

        if ($png -is [byte[]]) {
            [System.IO.File]::WriteAllBytes($path, $png)
            return $path
        }
    }

    if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
        $image = [System.Windows.Forms.Clipboard]::GetImage()
        if ($null -eq $image) {
            throw 'Clipboard reports an image but it could not be read.'
        }

        $path = Join-Path $tempDir ("clipboard_{0}.png" -f (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
        try {
            $image.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $image.Dispose()
        }
        return $path
    }

    if ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) {
        $files = [System.Windows.Forms.Clipboard]::GetFileDropList()
        foreach ($file in $files) {
            if ((Test-Path -LiteralPath $file) -and (Test-ImagePath $file)) {
                return (Convert-ToPngIfNeeded -Path $file)
            }
        }
    }

    throw "No image found in the Windows clipboard. Formats: $($formats -join ', '). Copy a screenshot or image first, then run /pasteimg again."
}

function Convert-ToAsciiEscaped {
    param([string]$Text)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int][char]$ch
        if ($code -eq 10) {
            [void]$sb.Append("`n")
        }
        elseif ($code -eq 13) {
            # Skip CR; LF is enough for Claude Code output.
        }
        elseif ($code -eq 9) {
            [void]$sb.Append("`t")
        }
        elseif ($code -ge 32 -and $code -le 126) {
            [void]$sb.Append($ch)
        }
        else {
            [void]$sb.Append(('\u{0:x4}' -f $code))
        }
    }
    return $sb.ToString()
}

function Repair-Mojibake {
    param([string]$Text)
    if (-not $Text) { return $Text }

    # Some Anthropic-compatible gateways return UTF-8 bytes without a charset.
    # Windows PowerShell may decode those bytes as Latin-1/ANSI, producing text
    # such as "ä½ å¥½". Repair only when the string strongly looks mojibaked.
    if ($Text -notmatch '[\u00c0-\u00ff]{2,}') {
        return $Text
    }

    $originalScore = ([regex]::Matches($Text, '[\u0080-\u00ff]')).Count
    foreach ($codePage in @(28591, 1252)) {
        try {
            $sourceEncoding = [System.Text.Encoding]::GetEncoding($codePage)
            $utf8 = New-Object System.Text.UTF8Encoding $false, $false
            $candidate = $utf8.GetString($sourceEncoding.GetBytes($Text))
            $candidateScore = ([regex]::Matches($candidate, '[\u0080-\u00ff]')).Count
            if ($candidate -and $candidateScore -lt $originalScore) {
                return $candidate
            }
        }
        catch {
            # Try the next candidate encoding.
        }
    }

    return $Text
}

function Get-ModelResponseText {
    param([object]$Response)

    $texts = @()

    if ($Response.content -is [string]) {
        $texts += [string]$Response.content
    }
    else {
        foreach ($item in @($Response.content)) {
            if ($null -eq $item) { continue }
            if ($item -is [string]) {
                $texts += [string]$item
            }
            elseif ($item.type -eq 'text' -and $item.text) {
                $texts += [string]$item.text
            }
            elseif ($item.text) {
                $texts += [string]$item.text
            }
        }
    }

    foreach ($choice in @($Response.choices)) {
        if ($choice.message.content) {
            $texts += [string]$choice.message.content
        }
        elseif ($choice.text) {
            $texts += [string]$choice.text
        }
    }

    if ($Response.output_text) {
        $texts += [string]$Response.output_text
    }
    if ($Response.text) {
        $texts += [string]$Response.text
    }

    return (($texts | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join "`n").Trim()
}

function Get-OptionalJson {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-FirstText {
    param([object[]]$Values)
    foreach ($value in $Values) {
        if ($null -ne $value) {
            $text = [string]$value
            if (-not [string]::IsNullOrWhiteSpace($text)) {
                return $text
            }
        }
    }
    return $null
}

function Get-FirstInt {
    param(
        [object[]]$Values,
        [int]$Default
    )
    foreach ($value in $Values) {
        if ($null -eq $value) { continue }
        $number = 0
        if ([int]::TryParse([string]$value, [ref]$number) -and $number -gt 0) {
            return $number
        }
    }
    return $Default
}

function Resolve-PasteImgConfig {
    $defaultConfigPath = Join-Path $skillRoot 'config.json'
    $effectiveConfigPath = Get-FirstText @($ConfigPath, $env:PASTEIMG_CONFIG, $defaultConfigPath)
    $config = Get-OptionalJson -Path $effectiveConfigPath

    $effectiveSettingsPath = Get-FirstText @(
        $SettingsPath,
        $env:PASTEIMG_CLAUDE_SETTINGS,
        (Join-Path $env:USERPROFILE '.claude\settings.json')
    )
    $settings = Get-OptionalJson -Path $effectiveSettingsPath

    $resolvedModel = Get-FirstText @(
        $VisionModel,
        $env:PASTEIMG_VISION_MODEL,
        $config.visionModel,
        $settings.env.PASTEIMG_VISION_MODEL,
        $settings.env.ANTHROPIC_DEFAULT_HAIKU_MODEL,
        $settings.env.ANTHROPIC_MODEL
    )

    $resolvedBaseUrl = Get-FirstText @(
        $BaseUrl,
        $env:PASTEIMG_ANTHROPIC_BASE_URL,
        $env:ANTHROPIC_BASE_URL,
        $config.baseUrl,
        $settings.env.ANTHROPIC_BASE_URL
    )

    $resolvedToken = Get-FirstText @(
        $AuthToken,
        $env:PASTEIMG_ANTHROPIC_AUTH_TOKEN,
        $env:ANTHROPIC_AUTH_TOKEN,
        $env:ANTHROPIC_API_KEY,
        $settings.env.ANTHROPIC_AUTH_TOKEN,
        $settings.env.ANTHROPIC_API_KEY
    )

    $resolvedMaxTokens = Get-FirstInt @(
        $MaxTokens,
        $env:PASTEIMG_MAX_TOKENS,
        $config.maxTokens
    ) 2048

    $defaultPrompt = @(
        'Read this image and output a complete English description for another model to continue reasoning from.',
        'Requirements:',
        '1. If the image contains text, code, errors, terminal output, or UI labels, transcribe them as accurately as possible.',
        '2. Describe the main interface, layout, buttons, state, colors, error messages, and any visible key details.',
        '3. If visible text contains non-ASCII characters, keep them exactly; the caller may escape them safely.',
        '4. Do not say that you cannot view the image; you are performing visual analysis.',
        '5. Output only the image content description. No greeting.'
    ) -join "`n"

    $resolvedPrompt = Get-FirstText @(
        $env:PASTEIMG_DESCRIPTION_PROMPT,
        $config.descriptionPrompt,
        $defaultPrompt
    )

    if (-not $resolvedBaseUrl) {
        throw 'Missing Anthropic-compatible base URL. Set PASTEIMG_ANTHROPIC_BASE_URL, ANTHROPIC_BASE_URL, config.json baseUrl, or ~/.claude/settings.json env.ANTHROPIC_BASE_URL.'
    }
    if (-not $resolvedToken) {
        throw 'Missing Anthropic auth token. Set PASTEIMG_ANTHROPIC_AUTH_TOKEN, ANTHROPIC_AUTH_TOKEN, ANTHROPIC_API_KEY, or ~/.claude/settings.json env.ANTHROPIC_AUTH_TOKEN.'
    }
    if (-not $resolvedModel) {
        throw 'Missing vision model. Set -VisionModel, PASTEIMG_VISION_MODEL, config.json visionModel, ~/.claude/settings.json env.PASTEIMG_VISION_MODEL, or ANTHROPIC_DEFAULT_HAIKU_MODEL.'
    }

    return [pscustomobject]@{
        VisionModel = $resolvedModel
        BaseUrl = $resolvedBaseUrl
        AuthToken = $resolvedToken
        MaxTokens = $resolvedMaxTokens
        Prompt = $resolvedPrompt
        ConfigPath = $effectiveConfigPath
        SettingsPath = $effectiveSettingsPath
    }
}

function Invoke-VisionDescription {
    param(
        [string]$ImagePath,
        [object]$Config
    )

    $bytes = [System.IO.File]::ReadAllBytes($ImagePath)
    $imageBase64 = [Convert]::ToBase64String($bytes)
    $mediaType = Get-MediaType -Path $ImagePath
    $url = $Config.BaseUrl.TrimEnd('/') + '/v1/messages'

    $headers = @{
        'Authorization' = 'Bearer ' + $Config.AuthToken
        'anthropic-version' = '2023-06-01'
        'content-type' = 'application/json'
    }

    $bodyObject = @{
        model = $Config.VisionModel
        max_tokens = $Config.MaxTokens
        messages = @(
            @{
                role = 'user'
                content = @(
                    @{
                        type = 'image'
                        source = @{
                            type = 'base64'
                            media_type = $mediaType
                            data = $imageBase64
                        }
                    },
                    @{
                        type = 'text'
                        text = $Config.Prompt
                    }
                )
            }
        )
    }

    $body = $bodyObject | ConvertTo-Json -Depth 20 -Compress
    try {
        $resp = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $body -TimeoutSec 120
    }
    catch {
        $status = ''
        if ($_.Exception.Response) {
            try { $status = [int]$_.Exception.Response.StatusCode } catch {}
        }
        throw "Vision request failed with model $($Config.VisionModel). Status=$status. $($_.Exception.Message)"
    }

    $description = Repair-Mojibake -Text (Get-ModelResponseText -Response $resp)
    if (-not $description) {
        throw "Vision request returned no text with model $($Config.VisionModel)."
    }
    return $description
}

if ($ImagePath) {
    if (-not (Test-Path -LiteralPath $ImagePath)) {
        throw "Image path does not exist: $ImagePath"
    }
    if (-not (Test-ImagePath -Path $ImagePath)) {
        throw "Unsupported image file extension: $ImagePath"
    }
    $savedImagePath = Convert-ToPngIfNeeded -Path $ImagePath
}
else {
    $savedImagePath = Save-ClipboardImage
}

if (-not $Describe) {
    Write-Output $savedImagePath
    exit 0
}

$resolvedConfig = Resolve-PasteImgConfig
$description = Invoke-VisionDescription -ImagePath $savedImagePath -Config $resolvedConfig
if ($NoEscape) {
    $safeDescription = $description
}
else {
    $safeDescription = Convert-ToAsciiEscaped -Text $description
}

Write-Output "PASTEIMG_IMAGE_PATH: $savedImagePath"
Write-Output "PASTEIMG_VISION_MODEL: $($resolvedConfig.VisionModel)"
Write-Output "PASTEIMG_DESCRIPTION_START"
Write-Output $safeDescription
Write-Output "PASTEIMG_DESCRIPTION_END"
