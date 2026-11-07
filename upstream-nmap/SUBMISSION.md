# Upstream Nmap submission package

Everything needed to contribute `ssh-sshhole.nse` to the Nmap project
(https://github.com/nmap/nmap). The script itself is the copy at the repo root
(`../ssh-sshhole.nse`, the single source of truth); it already carries the
`license = "Same as Nmap"` header. `submit_pr.sh` picks it up from there.

## Status / honesty note before you submit

- **No CVE yet.** The bug was fixed on 2026-11-05; a CVE may not be assigned at the
  time of reading. Upstream reviewers usually prefer a CVE in the `IDS`/references.
  Add it to the script (see "If/when a CVE is assigned" below) before or during
  review if one exists.
- **This is a banner/version check, not a prober.** It cannot confirm musl, PAM,
  config or accounts remotely without performing the bypass, which it deliberately
  does not do. The banner-shape grading (below) keeps false positives down by
  clearing glibc/BSD-tagged builds, but reviewers may still debate a `vuln`-category
  script that can only reach "LIKELY". Be ready to make that case, or to downgrade
  categories to `safe, version` if they prefer.

## Where the file goes

```
nmap/
  scripts/
    ssh-sshhole.nse     <-- add this file
    script.db           <-- regenerated; add the alphabetical entry (see below)
```

`script.db` is generated. After copying the script, regenerate it from a built
Nmap tree:

```sh
./nmap --script-updatedb      # writes scripts/script.db
```

or add the line manually in alphabetical order:

```
Entry { filename = "ssh-sshhole.nse", categories = { "safe", "version", "vuln", } }
```

## Testing evidence (done locally)

- `luac -p ssh-sshhole.nse` — clean.
- `nmap --script-help ssh-sshhole` — loads; categories `safe version vuln`.
- `test/run_tests.sh` (in the repo root) — 11/11 pass across banner shapes:
  Alpine-shape -> LIKELY; bare portable -> POSSIBLE; Debian/Ubuntu/FreeBSD tag ->
  NOT VULNERABLE; 7.3p1 and 10.6p1 boundaries -> in range; 7.2p1 and 10.6p2 ->
  out of range; dropbear -> "Not OpenSSH".
- Verified against **live Alpine 3.24 and 3.21** containers (musl, stock
  `openssh-server`, default config): banner is `OpenSSH_10.3` / `OpenSSH_9.9`
  (portable `pN` stripped) and the script returns LIKELY. The bypass itself was
  never run by the script.

## Suggested commit message

```
[NSE] Add ssh-sshhole.nse: detect *sshole OpenSSH musl auth bypass

Detection-only check for the 2026-11 OpenSSH password-authentication
bypass on musl systems without PAM (fixed in OpenSSH 10.6p2). Grades
risk from the version range (7.3p1..10.6p1) and the banner shape:
glibc/BSD build tags are cleared as not-musl; the bare, pN-stripped
banner that Alpine/musl emits is flagged LIKELY; a bare portable banner
is POSSIBLE. Never attempts the bypass or sends credentials.
```

## Paste-ready PR description

> ### Add ssh-sshhole.nse — detect the *sshole OpenSSH-on-musl password-auth bypass
>
> **What**
> A detection-only NSE script for the *sshole* vulnerability (https://sshhole.com):
> on musl systems (Alpine, OpenWrt, Buildroot, Yocto, ...) with sshd built without
> PAM and `PasswordAuthentication yes`, OpenSSH 7.3p1–10.6p1 authenticates any
> account whose password field is `*` when given a >256-byte password. Fixed in
> OpenSSH 10.6p2 (2026-11-05).
>
> **How it detects, safely**
> The script never attempts the bypass and sends no credentials. The decisive
> condition — musl libc — is not visible in the SSH protocol, so the script grades
> risk from the banner:
> - a glibc/BSD build tag (`Debian-`, `Ubuntu-`, `FreeBSD-`, ...) → **NOT VULNERABLE**
>   (the bug is musl-only and these platforms stamp their banner);
> - a bare banner with no `pN` suffix and no tag (e.g. `OpenSSH_10.3`) → **LIKELY**,
>   because Alpine/musl strips the portable suffix — verified against live Alpine
>   3.24/3.21, whose binary is `10.3p1`/`9.9p1` but whose banner is `10.3`/`9.9`;
> - a bare portable banner (`OpenSSH_10.3p1`) → **POSSIBLE** (any libc);
> - version outside 7.3p1..10.6p1 → **NOT VULNERABLE**.
>
> Even the strongest verdict is "verify locally", never "confirmed" — OpenBSD's
> native banner is indistinguishable from Alpine's but is not affected, and the
> `*`/donor-hash account preconditions are not remotely observable.
>
> **Categories** `safe, version, vuln`
> **Testing** `luac -p` clean; `--script-help` loads; a banner-shape test harness
> passes 11/11; verified against live Alpine containers. No bypass performed.
>
> **Caveat** The bug is very recent; if a CVE has been assigned I will add it to the
> references. Happy to adjust categories or wording per reviewer preference.
>
> References: https://sshhole.com · https://www.openssh.com/txt/release-10.6p2

## If/when a CVE is assigned

Add it to the script's NSEDoc references and (optionally) an `IDS` table:

```lua
-- in the @see / References block of the description, add:
--   https://nvd.nist.gov/vuln/detail/CVE-XXXX-NNNNN
-- and mention "CVE-XXXX-NNNNN" in the one-line verdict.
```

## Submitting

`./submit_pr.sh` forks `nmap/nmap` to your account (via `gh`), creates a branch,
copies the script into `scripts/`, commits and opens the PR with the description
above. Review it before running — it performs outward-facing GitHub actions.
