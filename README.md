# JDK Switcher for Windows ☕

> A lightweight, powerful PowerShell utility to switch between different Java Development Kits (JDKs) instantly.
> **No environment variable headaches.**

![PowerShell](https://img.shields.io/badge/PowerShell-%235391FE.svg?style=for-the-badge&logo=powershell&logoColor=white)
![Java](https://img.shields.io/badge/java-%23ED8B00.svg?style=for-the-badge&logo=openjdk&logoColor=white)

## ✨ Features

* **⚡ Instant Switching:** Changes `JAVA_HOME` and updates `PATH` immediately for the current session.
* **🔍 Auto-Discovery:** Automatically scans common installation paths (Program Files, AppData, .jdks) to find installed JDK versions.
* **🧹 Clean Environment:** Smartly removes old Java paths from System/User variables to prevent conflicts.
* **🛡️ Safety First:** Visual cues for Admin rights and critical warnings before deleting any files.
* **🎨 Beautiful UI:** Clean, tabular interface with color-coded status indicators.

## 🚀 Quick Start (Run without installing)

You can run the script directly from your terminal as Administrator without cloning the repository.
```powershell
irm https://raw.githubusercontent.com/nhatpse/jdk-switch/main/jdk-switch.ps1 | iex
```
* **Backup:** Universal Command (If Option 1 fails / For older Windows) Use this if you see SSL/TLS errors or Policy restrictions.
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('[https://raw.githubusercontent.com/nhatpse/jdk-switch/main/jdk-switch.ps1](https://raw.githubusercontent.com/nhatpse/jdk-switch/main/jdk-switch.ps1)'))```
