# ssh-sshhole.nse

An Nmap NSE **detection** script for the *sshole* OpenSSH password-authentication
bypass — **CVE-2026-123158** ([sshhole.com](https://sshhole.com), fixed in OpenSSH
10.6p2, 2026-11-05).

It is **detection-only**: it never attempts the bypass and never sends any
credentials. It reads the SSH identification banner and grades the risk from the
OpenSSH version and the banner *shape*.

## The bug, in one line

On **musl** systems (Alpine, OpenWrt, Buildroot, Yocto, ...) with sshd built
**without PAM** and `PasswordAuthentication yes`, OpenSSH 7.3p1–10.6p1 lets you log
in as any account whose password field is exactly `*` by sending a password longer
than 256 bytes. Affected accounts include `root` on Alpine cloud images and any
key-only / LDAP / AD user.

## Why detection is banner-based (and what that costs)

The decisive condition is **musl libc**, which is invisible in the SSH protocol.
Confirming musl + the absence of PAM + the `*`/donor-hash accounts can only be done
either **locally** (read `/etc/shadow`, `ldd` the binary — that is what the
project's `check.sh` does) or by **performing the bypass** (the attack). This
script does neither, so even its strongest verdict is "verify locally", never
"confirmed exploitable".

What it *can* do safely is use the banner shape, verified against live Alpine
containers:

| banner | verdict | reasoning |
|---|---|---|
| `OpenSSH_10.3p1 Debian-…` / `Ubuntu` / `FreeBSD` / `NetBSD` / `OpenBSD` … | **NOT VULNERABLE** | a glibc/BSD build tag; the bug is musl-only, and these platforms stamp their banner |
| `OpenSSH_10.3` — no `pN`, no tag | **LIKELY** | Alpine/musl strips the `pN` portable suffix and adds no tag; this is its exact shape (OpenBSD native looks the same but is not affected) |
| `OpenSSH_10.3p1` — has `pN`, no tag | **POSSIBLE** | an upstream/source build on any libc — could be musl or glibc |
| version `< 7.3p1` or `>= 10.6p2` | **NOT VULNERABLE** | outside the affected range |

The Alpine banner trait is the key signal: the binary is `OpenSSH_10.3p1` but the
on-wire banner is `SSH-2.0-OpenSSH_10.3`. This lets the script clear the
glibc-tagged majority of the internet (Debian/Ubuntu) instead of flagging it.

One more reason to confirm locally: **Alpine backported the fix into every branch
without changing the banner version** (a patched 3.24 still reports `OpenSSH_10.3`),
so an in-range banner does not prove the host is actually unpatched.

## Usage

```sh
# single host
nmap -p 22 -sV --script ./ssh-sshhole.nse <target>

# a subnet you are authorised to scan
nmap -p 22 -sV --script ./ssh-sshhole.nse 192.168.0.0/24
```

`-sV` is required so Nmap identifies the service as ssh.

Install it alongside the stock scripts:

```sh
sudo cp ssh-sshhole.nse "$(dirname "$(readlink -f "$(command -v nmap)")")/../share/nmap/scripts/" 2>/dev/null \
  || sudo cp ssh-sshhole.nse /usr/share/nmap/scripts/
sudo nmap --script-updatedb
nmap -p22 -sV --script ssh-sshhole <target>
```

To confirm a positive on a host you control, run the upstream project's
[`check.sh`](https://raw.githubusercontent.com/oz9un/sshole/main/check.sh) locally.

## Tests

`test/run_tests.sh` serves fake banners on local ports and asserts the verdict for
each banner shape — no real SSH server, no bypass:

```sh
./test/run_tests.sh            # uses ./ssh-sshhole.nse
```

## Upstream Nmap

A ready-to-submit package for the Nmap project lives in
[`upstream-nmap/`](upstream-nmap/) — the script with Nmap's license header, a
paste-ready PR description, placement and testing notes, and a helper that forks
`nmap/nmap` and opens the PR.

## Scope

Scan only hosts you own or are authorised to test. This is a version/banner check
for defenders; it is not an exploit.

## Licensing

`ssh-sshhole.nse` carries the `"Same as Nmap"` license line in its header so it can
be contributed upstream. The rest of this repository is MIT (see [LICENSE](LICENSE)).

## Credits

The *sshole* vulnerability, write-up, `check.sh` and PoC are by the original
researchers at [sshhole.com](https://sshhole.com) / `oz9un`. This repository only
adds an independent, non-exploiting Nmap detection script.
