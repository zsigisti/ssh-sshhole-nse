### Add ssh-sshhole.nse — detect the *sshole OpenSSH-on-musl password-auth bypass

**What**

A detection-only NSE script for the *sshole* vulnerability (https://sshhole.com):
on musl systems (Alpine, OpenWrt, Buildroot, Yocto, ...) with sshd built without
PAM and `PasswordAuthentication yes`, OpenSSH 7.3p1–10.6p1 authenticates any
account whose password field is `*` when given a >256-byte password. Fixed in
OpenSSH 10.6p2 (2026-11-05).

**How it detects, safely**

The script never attempts the bypass and sends no credentials. The decisive
condition — musl libc — is not visible in the SSH protocol, so the script grades
risk from the banner:

- a glibc/BSD build tag (`Debian-`, `Ubuntu-`, `FreeBSD-`, ...) → **NOT VULNERABLE**
  (the bug is musl-only and these platforms stamp their banner);
- a bare banner with no `pN` suffix and no tag (e.g. `OpenSSH_10.3`) → **LIKELY**,
  because Alpine/musl strips the portable suffix — verified against live Alpine
  3.24/3.21, whose binary is `10.3p1`/`9.9p1` but whose banner is `10.3`/`9.9`;
- a bare portable banner (`OpenSSH_10.3p1`) → **POSSIBLE** (any libc);
- version outside 7.3p1..10.6p1 → **NOT VULNERABLE**.

Even the strongest verdict is "verify locally", never "confirmed" — OpenBSD's
native banner is indistinguishable from Alpine's but is not affected, and the
`*`/donor-hash account preconditions are not remotely observable.

**Categories** `safe, version, vuln`

**Testing** `luac -p` clean; `--script-help` loads; a banner-shape test harness
passes 11/11; verified against live Alpine containers. No bypass performed.

**Caveat** The bug is very recent; if a CVE has been assigned I will add it to the
references. Happy to adjust categories or wording per reviewer preference.

References: https://sshhole.com · https://www.openssh.com/txt/release-10.6p2
