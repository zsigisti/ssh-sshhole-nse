#!/usr/bin/env bash
# Fork nmap/nmap, add ssh-sshhole.nse, and open a pull request.
#
# This performs OUTWARD-FACING GitHub actions (fork, push, open PR). It will not
# do anything until you pass --yes, so you can read it first.
#
#   ./submit_pr.sh            # dry run: prints exactly what it would do
#   ./submit_pr.sh --yes      # actually fork, push and open the PR
#
# Requires: gh (authenticated), git.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../ssh-sshhole.nse"   # single source of truth: repo root
PR_BODY="$HERE/pr-body.md"
WORK=${WORK:-/tmp/nmap-sshhole-pr}
BRANCH=${BRANCH:-nse-ssh-sshhole}
UPSTREAM=nmap/nmap
BASE=${BASE:-master}
TITLE="[NSE] Add ssh-sshhole.nse: detect *sshole OpenSSH musl auth bypass"
GO=${1:-}

command -v gh  >/dev/null || { echo "gh is required"; exit 1; }
command -v git >/dev/null || { echo "git is required"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "run: gh auth login"; exit 1; }
ME=$(gh api user -q .login)

echo "Will, as GitHub user '$ME':"
echo "  1. fork $UPSTREAM (if not already forked)"
echo "  2. clone your fork into $WORK (if absent) and branch '$BRANCH' off upstream/$BASE"
echo "  3. copy ssh-sshhole.nse into scripts/ and regenerate script.db if a built ./nmap exists"
echo "  4. commit, push to origin, and open a PR against $UPSTREAM:$BASE"
echo

if [ "$GO" != "--yes" ]; then
  echo "DRY RUN. Re-run with --yes to perform these actions."
  exit 0
fi

gh repo fork "$UPSTREAM" --clone=false >/dev/null 2>&1 || true

if [ ! -d "$WORK/.git" ]; then
  git clone "https://github.com/$ME/nmap.git" "$WORK"
fi
cd "$WORK"
git remote add upstream "https://github.com/$UPSTREAM.git" 2>/dev/null || true
git fetch upstream "$BASE"
git checkout -B "$BRANCH" "upstream/$BASE"

cp "$SCRIPT" scripts/ssh-sshhole.nse
if [ -x ./nmap ]; then
  ./nmap --script-updatedb || true
  git add scripts/ssh-sshhole.nse scripts/script.db
else
  echo "NOTE: no built ./nmap here; scripts/script.db NOT regenerated."
  echo "      Add this line to scripts/script.db alphabetically, or build and run"
  echo "      './nmap --script-updatedb' before the maintainers merge:"
  echo '      Entry { filename = "ssh-sshhole.nse", categories = { "safe", "version", "vuln", } }'
  git add scripts/ssh-sshhole.nse
fi

git commit -m "$TITLE" -m "Detection-only check for the 2026-11 OpenSSH password-auth bypass on musl without PAM (fixed in OpenSSH 10.6p2). Grades risk from the 7.3p1..10.6p1 version range and the banner shape; never attempts the bypass."
git push -u origin "$BRANCH"
gh pr create --repo "$UPSTREAM" --base "$BASE" --head "$ME:$BRANCH" \
  --title "$TITLE" --body-file "$PR_BODY"

echo "PR opened against $UPSTREAM."
