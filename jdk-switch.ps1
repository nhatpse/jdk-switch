# JDK-Switch v1.4 - AutoScan Integrated
# Run as Administrator for best results

# ================= CONFIG =================
$Base = "$env:USERPROFILE\.jdk-switch"
$Cfg  = "$Base\config.json"

# ================= CORE =================
function Initialize-Config {
    if (-not (Test-Path $Base)) {
        New-Item -ItemType Directory -Path $Base -Force | Out-Null
    }
    if (-not (Test-Path $Cfg)) {
        @() | ConvertTo-Json | Set-Content $Cfg -Encoding UTF8
    }
}

function Import-Config {
    Initialize-Config
    if (-not (Test-Path $Cfg)) {
        return @()
    }
    try {
        $content = Get-Content $Cfg -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($content) -or $content -eq "[]") {
            return @()
        }
        $parsed = $content | ConvertFrom-Json
        if ($parsed -is [System.Array]) {
            return $parsed
        } else {
            return @($parsed)
        }
    } catch {
        Write-Host "[ERROR] Failed to load config: $_" -ForegroundColor Red
        return @()
    }
}

function Save-Config($data) {
    Initialize-Config
    if ($null -eq $data) {
        $data = @()
    }
    if ($data -isnot [System.Array]) {
        $data = @($data)
    }
    $data | ConvertTo-Json -Depth 5 | Set-Content $Cfg -Encoding UTF8
}

function Find-Jdks {
    # Reduced verbosity for cleaner UI during auto-scan
    Write-Host "`n  [INFO] Auto-scanning system for JDKs..." -ForegroundColor Cyan
    
    $commonPaths = @(
        "C:\Program Files\Java",
        "C:\Program Files (x86)\Java",
        "C:\Program Files\Eclipse Adoptium",
        "C:\Program Files\Eclipse Foundation",
        "C:\Program Files\Amazon Corretto",
        "C:\Program Files\Zulu",
        "C:\Program Files\Microsoft",
        "$env:USERPROFILE\.jdks",
        "$env:LOCALAPPDATA\Programs\Java"
    )
    
    $list = @()
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            # Write-Host "  Scanning: $path" -ForegroundColor DarkGray # Commented out to reduce noise
            $jdkDirs = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue
            foreach ($dir in $jdkDirs) {
                $javaBin = Join-Path $dir.FullName "bin\java.exe"
                if (Test-Path $javaBin) {
                    try {
                        $versionOutput = & $javaBin -version 2>&1
                        $versionLine = $versionOutput | Select-Object -First 1
                        $cleanVersion = $versionLine.ToString().Trim() -replace '"', ''
                        
                        $list += [PSCustomObject]@{
                            name    = $dir.Name
                            path    = $dir.FullName
                            version = $cleanVersion
                        }
                        # Show a small dot or simple message for progress
                        Write-Host "    [+] Found: $($dir.Name)" -ForegroundColor Green
                    } catch {
                        # Write-Host "    Skipped: $($dir.Name)" -ForegroundColor DarkGray
                    }
                }
            }
        }
    }
    
    $list = $list | Sort-Object -Property path -Unique
    Save-Config $list
    return $list
}

function Show-JdkList {
    # INTEGRATION: Always run Find-Jdks first
    $jdks = Find-Jdks
    
    if ($jdks.Count -eq 0) {
        Write-Host "`n  [!] No JDKs found on this system." -ForegroundColor Red
        return
    }
    
    # Define Column Format: ID(5) Name(30) Version(15) Status(10)
    $RowFormat = "  {0,-5} {1,-30} {2,-15} {3,-10}"

    Write-Host "`n" -NoNewline
    $header = $RowFormat -f "ID", "NAME", "VERSION", "STATUS"
    Write-Host $header -ForegroundColor Cyan
    Write-Host ("  " + ("─" * 65)) -ForegroundColor DarkGray
    
    for ($i = 0; $i -lt $jdks.Count; $i++) {
        $id = ($i + 1).ToString()
        
        $name = $jdks[$i].name
        if ($name.Length -gt 28) { $name = $name.Substring(0, 25) + "..." }
        
        $ver = $jdks[$i].version
        if ($ver -match 'version ([^ ]+)') { $ver = $matches[1] }
        if ($ver.Length -gt 14) { $ver = $ver.Substring(0, 14) }

        $status = ""; $statusColor = "Gray"
        if ($env:JAVA_HOME -eq $jdks[$i].path) {
            $status = "[ACTIVE]"; $statusColor = "Green"
        }

        Write-Host ("  " + $id.PadRight(5)) -NoNewline -ForegroundColor Yellow
        Write-Host ($name.PadRight(30)) -NoNewline -ForegroundColor White
        Write-Host ($ver.PadRight(15)) -NoNewline -ForegroundColor Cyan
        Write-Host $status -ForegroundColor $statusColor

        Write-Host "       └─> $($jdks[$i].path)" -ForegroundColor DarkGray
        Write-Host ""
    }
    Write-Host ("  " + ("─" * 65)) -ForegroundColor DarkGray
    Write-Host "  Total: $($jdks.Count) JDK(s)" -ForegroundColor Gray
}

function Show-CurrentJdk {
    Write-Host "`n  ┌──────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "  │                 CURRENT JDK STATUS                       │" -ForegroundColor Cyan
    Write-Host "  └──────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
    
    $userJavaHome = [Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
    $machineJavaHome = [Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")
    
    $labels = @(
        @("JAVA_HOME (Session)", $env:JAVA_HOME, "Green"),
        @("JAVA_HOME (User)   ", $userJavaHome, "Gray"),
        @("JAVA_HOME (Machine)", $machineJavaHome, "Gray")
    )
    
    foreach ($item in $labels) {
        Write-Host "  » " -NoNewline -ForegroundColor Cyan
        Write-Host "$($item[0]) : " -NoNewline -ForegroundColor White
        $val = if ($item[1]) { $item[1] } else { "Not Set" }
        Write-Host $val -ForegroundColor $($item[2])
    }
    
    Write-Host "`n  { EXECUTABLE INFO }" -ForegroundColor Yellow
    try {
        $javaPath = (Get-Command java -ErrorAction SilentlyContinue).Source
        Write-Host "  Path: " -NoNewline -ForegroundColor DarkGray
        Write-Host $javaPath -ForegroundColor Gray
        
        Write-Host "  Ver : " -NoNewline -ForegroundColor DarkGray
        & java -version 2>&1 | Select-Object -First 1 | ForEach-Object { Write-Host $_.ToString().Trim() -ForegroundColor Gray }
    } catch {
        Write-Host "  [!] Java command not found in PATH" -ForegroundColor Red
    }
    Write-Host "  " + ("─" * 60) -ForegroundColor DarkGray
}

function Switch-Jdk {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "`n  [WARNING] Not running as Administrator." -ForegroundColor Yellow
        Write-Host "  System Path cannot be updated. Run PowerShell as Admin for best results." -ForegroundColor DarkGray
    }
    
    # We call Show-JdkList which now implicitly includes the Scan
    Show-JdkList
    
    # Reload config to get the array object for selection
    $jdks = Import-Config
    if ($jdks.Count -eq 0) { return }

    $choice = Read-Host "  Enter JDK ID to switch (0 to cancel)"
    
    if ($choice -eq "0" -or [string]::IsNullOrWhiteSpace($choice)) {
        Write-Host "  [CANCELLED] Operation cancelled." -ForegroundColor Yellow
        return
    }
    
    if (-not ($choice -as [int]) -or [int]$choice -lt 1 -or [int]$choice -gt $jdks.Count) {
        Write-Host "  [ERROR] Invalid selection." -ForegroundColor Red
        return
    }

    $selected = $jdks[[int]$choice - 1]

    Write-Host "`n  Selected: " -NoNewline -ForegroundColor Cyan
    Write-Host "$($selected.name)" -ForegroundColor White
    
    $confirm = Read-Host "  Confirm switch? (y/n)"
    if ($confirm -ne "y") {
        Write-Host "  [CANCELLED] Operation cancelled." -ForegroundColor Yellow
        return
    }

    Write-Host "`n  [INFO] Switching JDK..." -ForegroundColor Cyan
    
    try {
        # Step 1: Set JAVA_HOME
        Write-Host "  [1/5] Setting JAVA_HOME..." -ForegroundColor Cyan
        [Environment]::SetEnvironmentVariable("JAVA_HOME", $selected.path, "User")
        $env:JAVA_HOME = $selected.path
        Write-Host "    User JAVA_HOME set." -ForegroundColor Green
        
        # Step 2: Clean User PATH
        Write-Host "  [2/5] Cleaning User PATH..." -ForegroundColor Cyan
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $pathEntries = $userPath -split ";" | Where-Object { $_ }
        $cleanUserEntries = @()
        $removedUser = 0
        
        foreach ($entry in $pathEntries) {
            $isJavaPath = $entry -like "*\Java\*" -or 
                          $entry -like "*\jdk*" -or 
                          $entry -like "*\jre*" -or
                          $entry -like "*\Adoptium\*" -or
                          $entry -like "*\Corretto\*" -or
                          $entry -like "*\Zulu\*"
            
            if ($isJavaPath) {
                $removedUser++
            } else {
                $cleanUserEntries += $entry
            }
        }
        
        $newJavaPath = "$($selected.path)\bin"
        $newUserEntries = @($newJavaPath) + $cleanUserEntries
        $newUserPath = ($newUserEntries | Where-Object { $_ }) -join ";"
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
        Write-Host "    Cleaned $removedUser entries, added new bin." -ForegroundColor Green
        
        # Step 3: Clean System PATH
        Write-Host "  [3/5] Cleaning System PATH..." -ForegroundColor Cyan
        $finalMachinePath = ""
        
        if ($isAdmin) {
            $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            $machineEntries = $machinePath -split ";" | Where-Object { $_ }
            $cleanMachineEntries = @()
            $removedMachine = 0
            
            foreach ($entry in $machineEntries) {
                $isJavaPath = $entry -like "*\Java\*" -or 
                              $entry -like "*\jdk*" -or 
                              $entry -like "*\jre*" -or
                              $entry -like "*\Adoptium\*" -or
                              $entry -like "*\Corretto\*" -or
                              $entry -like "*\Zulu\*"
                
                if ($isJavaPath) {
                    $removedMachine++
                } else {
                    $cleanMachineEntries += $entry
                }
            }
            
            if ($removedMachine -gt 0) {
                $newMachinePath = ($cleanMachineEntries | Where-Object { $_ }) -join ";"
                [Environment]::SetEnvironmentVariable("Path", $newMachinePath, "Machine")
                Write-Host "    Removed $removedMachine system paths." -ForegroundColor Green
                $finalMachinePath = $newMachinePath
            } else {
                Write-Host "    No system Java paths found." -ForegroundColor Gray
                $finalMachinePath = $machinePath
            }
        } else {
            Write-Host "    Skipped (Not Admin)." -ForegroundColor Yellow
            $finalMachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        }
        
        # Step 4: Clean System JAVA_HOME
        Write-Host "  [4/5] Checking System JAVA_HOME..." -ForegroundColor Cyan
        $machineJavaHome = [Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")
        if ($machineJavaHome) {
            if ($isAdmin) {
                [Environment]::SetEnvironmentVariable("JAVA_HOME", $null, "Machine")
                Write-Host "    Removed System JAVA_HOME." -ForegroundColor Green
            } else {
                Write-Host "    System JAVA_HOME exists but cannot remove (Not Admin)." -ForegroundColor Yellow
            }
        }
        
        # Step 5: Update Session
        Write-Host "  [5/5] Updating current session..." -ForegroundColor Cyan
        if ($finalMachinePath) {
            $env:Path = $newUserPath + ";" + $finalMachinePath
        } else {
            $env:Path = $newUserPath
        }
        $env:JAVA_HOME = $selected.path
        
        Write-Host "`n  [✔] SUCCESS: JDK switched!" -ForegroundColor Green
        
        # Verify
        Write-Host "  [VERIFY] Checking java -version..." -ForegroundColor DarkGray
        $javaExe = "$($selected.path)\bin\java.exe"
        if (Test-Path $javaExe) {
            $v = & $javaExe -version 2>&1 | Select-Object -First 1
            Write-Host "  $v" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "`n  [ERROR] Failed to switch: $_" -ForegroundColor Red
    }
}

function Remove-Jdk {
    # Auto-scan first to ensure list is accurate before deleting
    Show-JdkList
    $jdks = Import-Config # Load fresh config

    if ($jdks.Count -eq 0) { return }

    $idx = Read-Host "`n  Select ID to REMOVE from disk (0 to cancel)"
    if ($idx -eq "0" -or -not ($idx -as [int]) -or $idx -lt 1 -or $idx -gt $jdks.Count) {
        return
    }

    $jdk = $jdks[[int]$idx-1]

    Write-Host "`n  " + ("!" * 40) -ForegroundColor Red
    Write-Host "  CRITICAL WARNING" -ForegroundColor Red
    Write-Host "  This will permanently DELETE the directory:" -ForegroundColor White
    Write-Host "  $($jdk.path)" -ForegroundColor Yellow
    Write-Host "  " + ("!" * 40) -ForegroundColor Red
    
    $confirm = Read-Host "`n  Type 'CONFIRM' to delete"
    if ($confirm -ne "CONFIRM") {
        Write-Host "  [Aborted] No changes made." -ForegroundColor Gray
        return
    }

    Write-Host "  [Deleting] Please wait..." -ForegroundColor DarkGray
    if (Test-Path $jdk.path) {
        Remove-Item $jdk.path -Recurse -Force
        Write-Host "  Directory deleted." -ForegroundColor Green
    }

    $new = $jdks | Where-Object { $_.path -ne $jdk.path }
    Save-Config $new
    Write-Host "  [✔] Removed successfully from list." -ForegroundColor Green
}

# ================= UI =================
function Show-Banner {
    Write-Host @"
      █████ ██████  ██   ██      ███████ ██     ██ ██ ████████  ██████ ██   ██
         ██ ██   ██ ██   ██      ██      ██     ██ ██    ██    ██      ██   ██
         ██ ██   ██ █████        ███████ ██  █  ██ ██    ██    ██      ███████
    ██   ██ ██   ██ ██  ██            ██ ██ ███ ██ ██    ██    ██      ██   ██
     █████  ██████  ██   ██      ███████  ███ ███  ██    ██     ██████ ██   ██
"@ -ForegroundColor Cyan

    Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   » JAVA DEVELOPMENT KIT MANAGER" -ForegroundColor White -NoNewline
    Write-Host " [v1.4]" -ForegroundColor DarkCyan
    Write-Host "  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Write-Host "   [✔] " -NoNewline -ForegroundColor Green
        Write-Host "STATUS: Running as Administrator" -ForegroundColor Gray
    } else {
        Write-Host "   [!] " -NoNewline -ForegroundColor Yellow
        Write-Host "STATUS: Running as User (Admin Recommended)" -ForegroundColor Yellow
    }

    $currentVer = "Unknown"
    try {
        $raw = & java -version 2>&1 | Select-Object -First 1
        if ($raw) { $currentVer = $raw.ToString().Trim() -replace '"','' }
    } catch {}

    Write-Host "   [●] " -NoNewline -ForegroundColor Cyan
    Write-Host "CURRENT: $currentVer" -ForegroundColor Gray
    Write-Host "  ──────────────────────────────────────────────────────────────────────`n" -ForegroundColor DarkGray
}

function Show-Menu {
    Write-Host "   SELECT AN OPTION:" -ForegroundColor DarkGray
    Write-Host ""
    
    $options = @(
        @("1", "Scan & List JDKs", "Cyan"),
        @("2", "Switch current JDK", "Cyan"),
        @("3", "Show detail current JDK", "Cyan"),
        @("4", "Remove a JDK", "Red"),
        @("0", "Exit Program", "DarkGray")
    )

    foreach ($opt in $options) {
        Write-Host "     [" -NoNewline -ForegroundColor White
        Write-Host "$($opt[0])" -NoNewline -ForegroundColor $($opt[2])
        Write-Host "] " -NoNewline -ForegroundColor White
        Write-Host "$($opt[1])" -ForegroundColor Gray
    }

    Write-Host "`n  ──────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
}

# ================= MAIN =================
Initialize-Config
$running = $true

do {
    Clear-Host
    Show-Banner
    Show-Menu
    
    $choice = Read-Host "   Choose an option (0-4)"

    switch ($choice) {
        "1" { Show-JdkList; Write-Host "`n  Press Enter to return..."; Read-Host }
        "2" { Switch-Jdk; Write-Host "`n  Press Enter to return..."; Read-Host }
        "3" { Show-CurrentJdk; Write-Host "`n  Press Enter to return..."; Read-Host }
        "4" { Remove-Jdk; Write-Host "`n  Press Enter to return..."; Read-Host }
        "0" { 
            $running = $false 
            Write-Host "`n  [!] Exiting program... Goodbye!" -ForegroundColor Cyan
            Start-Sleep -Milliseconds 800
        }
        default { 
            Write-Host "`n  [!] Invalid choice, please try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($running)