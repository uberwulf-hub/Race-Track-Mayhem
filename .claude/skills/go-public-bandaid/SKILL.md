---
name: go-public-bandaid
description: TEMPORARY BANDAID - not a real fix. Walks the owner through switching the Race-Track-Mayhem GitHub repo from private to public so release builds can keep running after the free GitHub Actions minutes for private repos run out, and back to private afterwards. Use when a Release/Android/Relay workflow won't start or fails because of the Actions minutes or spending limit, or when the user asks to make the repo public (or private again) to get past the GitHub limit. Always read the full warning to the user first, every time.
---

# Go public (TEMPORARY BANDAID)

> **This is a stopgap, not a solution.** Making the repo public removes the build-minute cap because GitHub
> doesn't charge minutes for public repos on its standard machines. It also exposes everything in the repo.
> Use it only to get a release out, and plan to switch back to private or apply a real fix (see the end).

## Rule: warn every single time

Before giving any steps, **always** tell the user, in plain words, that this is a temporary bandaid and
list the warnings below, even if they've seen them before and even if they're in a hurry. Never switch
visibility for them, never present it as the normal way to release, and never skip the warning because
"we did this last time". The user asked for this explicitly.

### Warnings and precautions to read out

1. **Everyone can see everything.** All code, files and the full history (old versions too) become public
   and can be copied or forked. Forks made while public stay public even after you switch back.
2. **Your Suno music becomes downloadable.** The song files in `assets/audio/music/` are "all rights reserved",
   but anyone can grab them while the repo is public. (A real fix: move the music out of the repo and have the
   build fetch it from a private place.)
3. **Check for secrets first.** Before switching, scan the full history for keys/passwords/tokens/keystores, e.g.:
   ```
   git log --all --name-only --format= | sort -u | grep -iE "keystore|\.jks|\.env|secret|credential|\.pem|\.key$"
   git log --all -p | grep -iE "(api[_-]?key|token|password)\s*[:=]\s*['\"][A-Za-z0-9_\-]{12,}"
   ```
   If anything turns up, **stop**: don't go public until it's removed and the secret is rotated.
   (Last scan, 2026-11-17: nothing found.)
4. **What stays private anyway:** repository/Actions secrets (Cloudflare token), the Android signing key in
   the Actions cache, the SauceStore listing.
5. **It's reversible but not undoable.** Switching back to private hides the repo again, but anything that was
   downloaded, cloned or forked while public is out there for good.
6. **Stars/watchers** are dropped when a public repo goes private (minor for this repo).

Then ask whether they still want to go ahead. Only continue on a clear yes.

## Steps (the user does these; Claude has no tool to change visibility)

1. Run the secret scan above and report the result.
2. User: open github.com/uberwulf-hub/Race-Track-Mayhem > **Settings** > **General** > scroll to
   **Danger Zone** > **Change visibility** > **Make public** > confirm.
3. Confirm it took effect with `list_repos` (query `race-track`): `visibility` should be `public`.
4. Re-run the release (see the `release` skill).
5. **Remind the user to switch back** once the release is out (same place, **Make private**), unless they
   choose to stay public. Offer to schedule a reminder (`send_later`) for when the monthly minutes reset
   (start of the next billing month).

## Real fixes to suggest instead (every time)

- Wait for the monthly free minutes to reset (GitHub Settings > Billing shows usage and the reset date).
- Set a small Actions spending limit in GitHub billing so private builds keep running (a release is ~8 minutes).
- Cut minutes per release: cache more of the build, skip the wine/rcedit install when the icon isn't needed.
- Move the Suno music out of the repo so going public later wouldn't expose it.
