# Configuration
$githubUser = "contrun"
$keysUrl = "https://github.com/$githubUser.keys"

# Fetch public SSH keys from GitHub
try {
    $ProgressPreference = 'SilentlyContinue'
    $webResponse = Invoke-WebRequest -Uri $keysUrl -UseBasicParsing -ErrorAction Stop
    $keys = $webResponse.Content -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
}
catch {
    throw "Failed to fetch SSH keys from ${keysUrl}: $_"
}

if (-not $keys) {
    throw "No SSH keys found at $keysUrl"
}

# Define target SSH key locations and their required owner groups
$targets = @(
    @{ Path = "$env:USERPROFILE\.ssh\authorized_keys"; Group = "$env:USERNAME" },
    @{ Path = "$env:ProgramData\ssh\administrators_authorized_keys"; Group = "BUILTIN\Administrators" }
)

# Process each target file
foreach ($target in $targets) {
    $filePath = $target.Path
    $dirPath = Split-Path -Path $filePath -Parent

    # Ensure parent directory exists
    if (-not (Test-Path -Path $dirPath)) {
        New-Item -Path $dirPath -ItemType Directory -Force | Out-Null
    }

    # Ensure target file exists
    if (-not (Test-Path -Path $filePath)) {
        New-Item -Path $filePath -ItemType File -Force | Out-Null
    }

    # Add SSH keys idempotently
    $existing = Get-Content -Path $filePath -ErrorAction SilentlyContinue
    foreach ($key in $keys) {
        if ($existing -notcontains $key) {
            Add-Content -Path $filePath -Value $key -Encoding utf8
        }
    }

    # Harden Access Control Lists (ACL)
    $acl = Get-Acl -Path $filePath
    $acl.SetAccessRuleProtection($true, $false)
    $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) } | Out-Null

    $sysRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        "NT AUTHORITY\SYSTEM", "FullControl", "Allow"
    )
    $groupRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $target.Group, "FullControl", "Allow"
    )

    $acl.AddAccessRule($sysRule)
    $acl.AddAccessRule($groupRule)
    Set-Acl -Path $filePath -AclObject $acl
}
