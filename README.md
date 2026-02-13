# screentime

Arch Linux screen-time enforcement for a single user on GNOME 49+.

Features:
- Per-weekday minute limits
- Daily reset time (default 06:00)
- GNOME notification at 10 minutes remaining
- Auto-logout at 0 minutes
- PAM login blocking when limit is reached

## Quick start

1. Run installer locally (or via SSH):

```bash
./setup.sh
```

2. Edit `/etc/screentime.conf` if needed.

3. Check status:

```bash
systemctl status screentime.timer
```

## Files

- `bin/screentime-daemon`: minute-based enforcement
- `bin/screentime-check`: PAM account check
- `systemd/screentime.service` and `systemd/screentime.timer`
- `etc/screentime.conf.template`

## Notes

- Notification uses `notify-send` on the user session bus.
- Login blocking uses PAM `pam_exec.so` in account phase.
