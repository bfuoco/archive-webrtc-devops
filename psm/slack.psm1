<#
Tests whether or not Slack is configured properly.
#>
function Test-Slack
{
    Write-Host "`nChecking if Slack API token is set:"

    if (Test-Path Env:WEBRTC_SLACK_API_TOKEN)
    {
        Write-Host -ForegroundColor DarkGray "`tWEBRTC_SLACK_API_TOKEN : <<hidden>>"
    }
    else
    {
        throw "Environment variable WEBRTC_SLACK_API_TOKEN variable is not set."
    }
}

function Get-SuccessEmoji
{
    @(":smile:", ":simple_smile:", ":smiley:", ":grinning:", ":slightly_smiling_face:", ":grin:", ":kissing_smiling_eyes:")
}

function GetFailureEmoji
{
    @(":disappointed:", ":confounded:", ":weary:", ":worried:", ":rage:", ":tired_face:", ":unamused:", ":anguished:")
}

<#
Sends a Slack notification.
#>
function Send-Notification
{
    Param([string]$Name, [string[]]$Emojis, [string]$Message)

    $Emoji = $Emojis[(Get-Random $Emojis.Length)]
    $Message = $Message.Replace("""", "\""")

    $Body = "{""username"": ""$Name"", ""icon_emoji"": ""$Emoji"", ""text"": ""$Message""}"

    $Result = Invoke-WebRequest -Method "POST" -Body $Body "https://hooks.slack.com/services/$($Env:WEBRTC_SLACK_API_TOKEN)"
}

Export-ModuleMember -function Test-Slack
Export-ModuleMember -function Get-SuccessEmoji
Export-ModuleMember -function Get-FailureEmoji
Export-ModuleMember -function Send-Notification
