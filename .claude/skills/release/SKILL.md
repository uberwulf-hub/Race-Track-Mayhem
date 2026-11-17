---
name: release
description: Publish a new version of Race Track Mayhem to the public (GitHub release, picked up by SauceStore) - version bump, push, run the Release workflow, verify both the Windows zip and Android APK are attached, and deploy the race server when online code changed. Use when asked to release, publish, ship, or "put out" a new version, or after finishing a round of changes that should reach players.
---

# Releasing Race Track Mayhem

Players get updates from **SauceStore**, which reads the repo's latest public GitHub release
(uberwulf-hub/Race-Track-Mayhem) about every 10 minutes. A release must carry **both**
`RaceTrackMayhem-windows.zip` and `RaceTrackMayhem-android.apk` (names come from `saucestore.json` > `assets`).

## Steps

1. **Test first.** Run the changed screens headless under xvfb at the user's window size (1510x930) and
   look at screenshots:
   `xvfb-run -a godot --rendering-driver opengl3 --resolution 1510x930 -s <test_script.gd>`
   - `RACE_NO_FRIENDS=1` stops friend polling during tests.
   - For online tests use the local relay: `cd server/relay && npx wrangler dev -c wrangler.local.toml --port 8799`
     and run the game with `RACE_RELAY_URL=ws://localhost:8799` (the sandbox can't reach the live relay from Godot).
2. **Pick the version** (vX.Y.Z): patch for fixes, minor for new features. Look at the latest release
   (`get_latest_release`) so you don't reuse a tag. Set `config/version="X.Y.Z"` in `project.godot`
   (the workflow also stamps it, but keep the repo in step).
3. **If online play changed** in a way old copies can't race with, bump `PROTOCOL` in `scripts/net.gd`.
   If the race server's message format changed, bump `RELAY_PROTOCOL` and deploy the relay (step 7) **before**
   the release goes out.
4. **Update README.md** for any player-visible feature.
5. **Commit and push** to the development branch (currently `ccr-71edb9d0-e0f2fq`, which is also the default
   branch, so no PR). Write commit messages in plain words a parent could read.
6. **Run the Release workflow** (GitHub MCP `actions_run_trigger`, method `run_workflow`,
   `workflow_id: release.yml`, `ref: <branch>`, `inputs: {"version": "vX.Y.Z"}`). Pushing a `v*` tag also works.
   - Job `windows`: export, zip, `gh release create` (creates the public release and tag).
   - Job `android` (from `android.yml`, runs after windows): builds the APK with the saved signing key and
     attaches it to the same release.
   - Normal run: about 8 minutes total. Don't poll in a loop; schedule a check-in (`send_later`, ~8 min).
7. **Deploy the race server only if `server/relay/` changed:**
   ```
   cd server/relay
   CLOUDFLARE_API_TOKEN=proxy-injected CLOUDFLARE_ACCOUNT_ID=<account id> \
   NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt npx wrangler deploy
   ```
   The real token is injected by the session's network proxy (saved as a network secret on the environment);
   never ask for it in chat or write it anywhere. The account ID is in this session's earlier deploys or the
   Cloudflare dashboard. Alternative: Actions > "Relay server" workflow (`relay.yml`) uses repo secrets.
   New Durable Object classes need a new `[[migrations]]` tag in both `wrangler.toml` and `wrangler.local.toml`.
   Smoke-test the live endpoint with curl afterwards.
8. **Verify** with `get_release_by_tag`: both assets present, `state: uploaded`, sensible sizes
   (Windows zip ~59 MB, APK ~74 MB as of v1.19.1). Then tell the user in plain words what's in the
   release and that SauceStore will show it within ~10 minutes.

## Known problems

- **Out of GitHub Actions minutes** (workflow won't start, or fails mentioning minutes/spending limit/billing):
  the repo is private, and private repos get a limited number of free build minutes a month. Use the
  `go-public-bandaid` skill. It's a TEMPORARY bandaid: always give the user its full warning first and
  suggest the real fixes.

- **No icon tool in the build (on purpose):** to save build minutes, the Windows build no longer installs
  wine/rcedit, and `application/modify_resources=false` in `export_presets.cfg`. The .exe file shows Godot's
  default icon in File Explorer; the game window still uses the game's icon. Don't add it back without asking.
- **A run stuck far longer than usual:** cancel it (`cancel_workflow_run`), read the logs (`get_job_logs`),
  fix, and re-run with the same version (the release isn't created until the last step, so re-running is safe).
- **Release already exists for that tag**: `gh release create` fails. Use the next patch version rather
  than deleting a public release.
- **Android signing key**: kept in the Actions cache and refreshed by `keep-android-key.yml` every 3 days.
  If it's ever lost, phones must uninstall (losing saves) to update; a permanent key is still an open
  decision for the user. Never put a key or keystore password in the repo or in chat.
