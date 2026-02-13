# Arch Linux Screen-Time Enforcement + Installer Repo

## Summary
Create a new git repo at `/home/taaniel/repos/screentime` containing the screentime scripts, config template, systemd units, and a `setup.sh` installer that applies them on the local machine (typically invoked via SSH). The solution enforces per-weekday limits with a 06:00 reset, GNOME 49+ notification at T-10, logout at 0, and PAM login denial when limits are exhausted.

## Repo Layout (Public Interface)
```
/home/taaniel/repos/screentime/
  README.md
  .gitignore
  setup.sh
  etc/
    screentime.conf.template
  systemd/
    screentime.service
    screentime.timer
  bin/
    screentime-daemon
    screentime-check
```

## Functional Behavior (unchanged core)
- Single user target, configured in `/etc/screentime.conf`
- Per-day total usage, counted while any session is active
- Reset at 06:00 local time
- One dismissable GNOME notification at 10 minutes remaining
- Logout via `loginctl terminate-session`
- PAM account deny with warning when remaining <= 0

## Installer `setup.sh`
### Purpose
Idempotent local installer that:
1. Checks requirements (systemd, loginctl, python3, notify-send).
2. Copies binaries to `/usr/local/bin/`.
3. Installs `/etc/screentime.conf` from template, prompting for username and weekday limits.
4. Installs systemd units to `/etc/systemd/system/`.
5. Adds PAM account hook to `/etc/pam.d/system-login` (and `gdm-password` if present), with a backup.
6. Reloads systemd, enables and starts `screentime.timer`.

### Execution Model
- Run locally; user may run it over SSH (e.g., `ssh host 'bash -s' < setup.sh`).
- Uses `sudo` for privileged operations when required.
- Safe/idempotent: re-running doesn't duplicate PAM entries or break existing units.

## Important Changes / Interfaces
- New config file: `/etc/screentime.conf`
- New state file: `/var/lib/screentime/<user>.json`
- New binaries: `/usr/local/bin/screentime-daemon`, `/usr/local/bin/screentime-check`
- New systemd units: `screentime.service`, `screentime.timer`
- PAM modification: `/etc/pam.d/system-login` (and `gdm-password` if present)

## PAM Integration Details
- Use `pam_exec.so` in `account` phase to call `screentime-check`.
- The script prints a clear warning to stderr on deny.
- Add only one entry; detect and skip if already present.
- Back up PAM files before editing.

## Test Cases and Scenarios
1. `setup.sh` on a clean system installs all files and enables timer.
2. Re-running `setup.sh` is idempotent (no duplicate PAM lines).
3. With a short limit (e.g., 2 minutes), warning at T-10 is suppressed; logout still works at 0.
4. At 10 minutes remaining, a single GNOME notification appears and is dismissable.
5. Login blocked when remaining <= 0 with proper PAM message.
6. Reset at 06:00: usage before 06:00 counts toward previous day.
7. No session: usage does not advance.

## Assumptions and Defaults
- Target OS: Arch Linux with systemd.
- GNOME 49+ installed for notifications.
- `notify-send` available (from `libnotify`).
- Python3 available.
- User will provide username and weekday minutes during setup.

## Out of Scope
- Multi-user enforcement.
- Idle-aware counting.
- Remote orchestration beyond local installer usage via SSH.

## Decisions Locked
- Repo location: `/home/taaniel/repos/screentime`
- Installer mode: local install (can be invoked over SSH)
- Privilege handling: `sudo` when needed
- Git: `git init` with `README.md` and `.gitignore`
- Systemd: enable and start timer immediately
