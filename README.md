# nt4AliveRev (`NT4Alive` Revised)

A modernized Windows batch script suite for **Windows 7, 8, 10, and 11 (x86 & x64)** that slipstreams Service Pack 6a, post-SP6a hotfixes, Windows Installer 2.0, optional Windows 2000 boot loaders, and modern storage/USB drivers into **Windows NT 4.0** (Workstation, Server, and Terminal Server Edition).

Derived from the classic 2008 `NT4Alive` script by **Tomcat76 / FDV / TommyP**, updated to eliminate legacy XP-era binary dependencies (`ModifyPE.exe`, manual ISO extraction, 32-bit-only helpers) in favor of built-in Windows PowerShell and modern tooling.

---

## Scripts Included

| Script | Purpose |
| :--- | :--- |
| **`nt4AliveRev.cmd`** | Main slipstreamer. Extracts your NT 4.0 ISO, integrates SP6a, Q299444, hotfixes, Windows Installer 2.0, and optional Windows 2000 boot files, patches `oleaccrc.dll` PE checksums natively via `imagehlp.dll`, updates the `SOFTWARE` registry hive, and builds a bootable ISO (`NT4SP6W.iso`, `NT4SP6S.iso`, or `NT4SP6T.iso`). |
| **`nt4AliveRevDrivers.cmd`** | Companion driver integrator. Downloads and slipstreams the [ages2001](https://github.com) NT 4.0 storage and USB drivers (`AHCINT`, `NVMENT`, `IDENT`, `MMCSDNT`, and `USBNT`) plus any custom files from `DRIVERS\CUSTOM\`, outputting `NT4SP6W+.iso`, `NT4SP6S+.iso`, or `NT4SP6T+.iso`. |
| **`nt4AliveRevClean2K.cmd`** | Optional companion utility. Extracts only `CDROM_NT.5`, `I386\NTLDR`, `I386\NTDETECT.COM`, and the El Torito boot sector from a full Windows 2000 ISO to create a ~300 KB stub ISO (`nt4AliveRevClean2K.iso`) for reuse with `nt4AliveRev.cmd`. |

---

## System Requirements

* **Host OS:** Windows 7 (RTM or SP1), Windows 8 / 8.1, Windows 10, or Windows 11 (32-bit or 64-bit).
* **Privileges:** Administrator rights (required to mount and update the offline NT 4.0 `SOFTWARE` registry hive via `reg.exe`).
* **7-Zip:** Installed in `Program Files` / `Program Files (x86)`, or `7z.exe` + `7z.dll` placed in the script folder or `TOOLS\`.
* **ISO Creation Tool:** `oscdimg.exe` (auto-detected from the script folder, `TOOLS\`, or local Windows ADK installations; `nt4AliveRev.cmd` and `nt4AliveRevClean2K.cmd` also offer to download `oscdimg.exe` directly from Microsoft if missing) or `CDIMAGE.EXE` in `TOOLS\`.

---

## Quick Start

### 1. Prepare Your Working Folder
Place the `.cmd` scripts in a clean working folder alongside:
* Your **Windows NT 4.0 ISO** (Workstation, Server, or Terminal Server)
* **Service Pack 6a:** `sp6ai386.exe` (for Workstation/Server) or `wtsi386.exe` (for Terminal Server)
* *(Optional)* Any post-SP6a hotfixes (`*299444*.exe`, `*q*i.exe`, `WindowsNT4*.exe`, `InstMsiW.exe`) inside `PACKAGES\` (or `PACKAGES_TS\` for Terminal Server)
* *(Optional)* A **Windows 2000 ISO** if you want to integrate Windows 2000's `BOOT.BIN`, `NTLDR`, and `NTDETECT.COM` for improved ACPI/hardware boot compatibility

### 2. *(Optional)* Slim Down Your Windows 2000 ISO
Run **`nt4AliveRevClean2K.cmd`** to generate `nt4AliveRevClean2K.iso` (~300 KB). Your original Windows 2000 ISO is left untouched and can be archived elsewhere.

### 3. Build the Base SP6a Slipstreamed ISO
Right-click **`nt4AliveRev.cmd`** and select **Run as administrator**.
* Follow the prompts to integrate Windows 2000 boot loaders (`[Y/N]`) if desired.
* When complete, your bootable ISO (`NT4SP6W.iso`, `NT4SP6S.iso`, or `NT4SP6T.iso`) will be created in the same folder.

### 4. *(Optional)* Integrate Modern Storage & USB Drivers
Right-click **`nt4AliveRevDrivers.cmd`** and select **Run as administrator**.
* Choose **`Y`** when prompted to automatically fetch the `ages2001` driver suite (`AHCINT` SATA AHCI, `NVMENT` NVMe, `IDENT` IDE, `MMCSDNT` SD/SDHC/SDXC, and `USBNT` USB 1.1–4/Thunderbolt) from GitHub.
* Drop any additional custom driver files into `DRIVERS\CUSTOM\` if desired.
* The script will generate **`NT4SP6W+.iso`** (or `S+` / `T+`).

> **Post-Install Note for `USBNT`:** After reaching the Windows NT 4.0 desktop for the first time, **reboot once** before installing VMware Tools, VirtualBox Guest Additions, or other hardware drivers so `USBNT` finishes initializing cleanly.

---

## Configuration (`TOOLS\SETTINGS.INI`) & Automation

On first run, `nt4AliveRev.cmd` automatically generates `TOOLS\SETTINGS.INI` with default values. You can edit this file to customize ISO creation or skip interactive prompts:

```ini
; nt4AliveRev Settings
CREATE_ISO=YES
CDIMAGE_SWITCHES=-h -j1 -m -o -e
;USE_W2K_BOOT=YES
;ISO_FILE_NAME=NT4SP6W.iso
;ISO_VOLUME_LABEL=NT4SP6W
```

| Setting | Values | Description |
| :--- | :--- | :--- |
| **`CREATE_ISO`** | `YES` / `NO` | Controls whether a bootable `.iso` is built after slipstreaming completes (default: `YES`). |
| **`CDIMAGE_SWITCHES`** | String | Flags passed to `oscdimg.exe` / `CDIMAGE.EXE` (default: `-h -j1 -m -o -e`). Both `nt4AliveRev.cmd` and `nt4AliveRevDrivers.cmd` read this setting. |
| **`USE_W2K_BOOT`** | `YES` / `NO` | Optional. If omitted, `nt4AliveRev.cmd` prompts interactively (`[Y/N]`). Setting `YES` or `NO` forces that behavior without prompting. |
| **`ISO_FILE_NAME`** | Filename | Optional. Overrides the auto-detected output filename (`NT4SP6W.iso`, `NT4SP6S.iso`, or `NT4SP6T.iso`). |
| **`ISO_VOLUME_LABEL`** | Label | Optional. Overrides the auto-detected ISO volume label (`NT4SP6W`, `NT4SP6S`, or `NT4SP6T`). |

### Command-Line `RUNMODE` Options
You can also pass a `RUNMODE` environment variable before launching `nt4AliveRev.cmd` from an elevated Command Prompt:
* **`SET RUNMODE=SKIPINTRO`** — Skips the intro banner and starts immediately.
* **`SET RUNMODE=FULLAUTO`** — Runs unattended (skips the intro banner and final "Press any key to quit" pause; pair with `USE_W2K_BOOT=YES` or `NO` in `SETTINGS.INI` for zero prompts).
* **`SET RUNMODE=D`** — Runs in debug mode and logs full verbose output to `DEBUG.TXT` (same as typing `D` at the intro prompt).

---

## Credits & License

* **Original `NT4Alive` (2008):** Tomcat76, FDV, and TommyP — licensed under **GNU GPLv2**.
* **NT 4.0 Storage & USB Drivers:** [Atakan Gesmeli (`ages2001`)](https://github.com).
* **License:** This project is licensed under the **GNU General Public License v2.0** — see the [LICENSE](LICENSE) file for details.
