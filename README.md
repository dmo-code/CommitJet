# CommitJet

A native macOS menu bar app for reviewing Git changes and creating local commits. CommitJet supports selective staging, local branch management, fetching and fast-forwarding remote changes, pushing to a configured remote, and optional commit message suggestions from Ollama.

## Product preview

See the [CommitJet product page](https://dmo-code.github.io/CommitJet/) for an illustrative interface preview with light and dark themes. It uses sample data and is not a live app screenshot.

## Product page

The static product page lives in `docs/` and is available in German and English, with language and theme choices saved in the browser. Its illustrative app preview follows the selected light or dark theme and uses sample data. In the repository settings, choose **Settings → Pages → GitHub Actions** as the build and deployment source. The workflow in `.github/workflows/pages.yml` publishes updates from `main` whenever `docs/` changes. The public page is <https://dmo-code.github.io/CommitJet/>.

## Requirements

- macOS 13 or later
- Xcode 27.2 or a compatible recent Xcode with Swift 6
- Git available at `/usr/bin/git`
- Ollama is optional; the default server is `http://localhost:11434`

The app uses SwiftUI `MenuBarExtra` with the native window style and has no Dock icon or persistent main window. The deployment target is macOS 13.

## Build and run

1. Open `CommitJet.xcodeproj` in Xcode.
2. Select the **CommitJet** scheme and run it, or build with:

   ```sh
   xcodebuild -project CommitJet.xcodeproj -scheme CommitJet -destination 'platform=macOS' -derivedDataPath /tmp/CommitJetDerived CODE_SIGNING_ALLOWED=NO build
   ```

The app appears in the menu bar. Choose a local Git repository to see its current branch, changed-file count, and an expandable, scrollable list of changed paths and statuses. Select files and use **Stage selected** or **Unstage selected** to manage the Git staging area. Commits and AI message suggestions use staged changes only. Select the branch name to search, create, switch, or delete local branches. Git keeps compatible working-tree changes and blocks a switch if it would overwrite them. Enter a commit message, then select **Commit**. When the tracked remote branch is ahead, choose **Pull remote changes** to fetch and fast-forward the current branch. When local commits are ready, the main action offers synchronization or branch publishing. On the first commit in each repository, confirm that the staged changes should be committed. Select **Don't show again** in that warning to suppress it for future commits; you can restore confirmations in Settings.

## GitHub releases without Developer ID signing

CommitJet is distributed outside the App Store with an ad-hoc signature. It is not signed with a Developer ID certificate or notarized, so macOS may show a security warning when you first open it. No Apple Developer account is required for this release path. The app targets macOS 13 and later and is packaged for both Apple silicon and Intel Macs.

To build a release ZIP locally:

```sh
   ./scripts/package-release.sh 1.0.2
```

The script writes `CommitJet-1.0.2-macOS.zip` and its SHA-256 checksum under `.build/releases/`. To publish a GitHub Release, push a version tag after committing the release changes:

```sh
git tag v1.0.2
git push origin v1.0.2
```

Pushing a `v*` tag runs the GitHub Actions release workflow, which builds the app with an ad-hoc signature and attaches the ZIP and checksum to a GitHub Release. If `.github/release-notes/<tag>.md` exists, the workflow uses it as the release description; otherwise it generates notes from the commits.

CommitJet checks GitHub Releases for updates when Settings opens. If a newer version is available, Settings shows its release notes and can download the macOS ZIP with a visible progress indicator. Before saving the ZIP to Downloads, CommitJet verifies it against the release's SHA-256 checksum. Open the downloaded ZIP and move `CommitJet.app` to Applications to replace the installed version.

### Opening the downloaded app

Because CommitJet is not signed with a Developer ID certificate or notarized, macOS may say that Apple cannot check it for malicious software. If you downloaded CommitJet from the official [GitHub Releases page](https://github.com/dmo-code/CommitJet/releases) and want to open it:

1. Double-click the downloaded ZIP to extract `CommitJet.app`, then move the app to your **Applications** folder.
2. Try to open CommitJet once. When macOS shows the warning, click **Done**; do not choose **Move to Trash**.
3. Open **Apple menu → System Settings → Privacy & Security** and scroll down to the **Security** section.
4. Click **Open Anyway** (German: **Dennoch öffnen**) next to the message about CommitJet.
5. Confirm the warning that appears again by clicking **Open**. Enter your Mac password if requested.

After you approve it this way, you can open CommitJet normally. This approval is needed once on each Mac. See [Apple's guidance for opening apps](https://support.apple.com/en-us/102445).

To start CommitJet automatically when you sign in to your Mac, enable **Launch at login** in Settings. macOS may ask you to allow it under **System Settings → General → Login Items**.

## Ollama

Start Ollama locally, install a model (for example `ollama pull qwen2.5-coder`), then open CommitJet's Settings. Keep the server address at `http://localhost:11434`, load models, and select one. Choose English or German as the interface and commit message language, then choose a short, normal, or detailed suggestion. Short produces a concise subject only; normal adds a brief body when it provides useful context; detailed adds relevant context and effects supported by the changes. The selected detail level is shown beside the Sparkles button and in the ready-to-review status. When the suggestion is ready, CommitJet can show a macOS notification; you can edit the message before committing. In-app Help explains repository selection, message generation, privacy, and confirmation settings.

AI generation is optional and only runs after clicking Sparkles. A remote server address triggers a privacy notice; the diff is sent only to that configured endpoint. The response timeout defaults to 120 seconds and can be set from 45 to 600 seconds in Settings. Diffs larger than 150 KB are refused.

## Privacy

CommitJet has no telemetry, accounts, or cloud services of its own. It does not send Git data automatically. When you request an AI suggestion, the staged diff is sent only to the Ollama address configured in Settings; localhost is the default. Repository content is not written to app logs. Git diff content is treated as untrusted prompt data and cannot trigger app actions.

## Git behavior and limitations

- CommitJet creates local commits, creates, switches, and deletes local branches, fetches from the configured upstream, and fast-forwards the current branch when it is only behind. If local and remote commits have diverged, or Git cannot safely update the working tree, CommitJet stops and asks you to resolve the situation in another Git client. **Sync changes** pushes local commits to the configured remote; a branch without an upstream is published to the first configured remote.
- A commit includes only staged changes. Stage selected files to add their current contents to the index, or unstage them to keep those changes out of the commit. The AI suggestion also uses only the staged diff.
- The first commit in each repository requires confirmation unless you suppress the warning. Changed submodules, unresolved conflicts, and active merge/rebase/cherry-pick/revert/bisect states are refused.
- Before committing, CommitJet checks that the staged diff still matches the analyzed AI diff.
- If Git reports errors (for example missing author identity), CommitJet shows the Git error. The app never changes Git configuration.
- CommitJet is not sandboxed so it can run the local Git CLI and access the repository selected by the user. Only local selected repository paths are passed to Git.

## Tests

Run the unit tests with:

```sh
xcodebuild -project CommitJet.xcodeproj -scheme CommitJet -destination 'platform=macOS' -derivedDataPath /tmp/CommitJetDerived test
```

Tests use disposable local repositories under the system temporary directory.

## License

MIT. See [LICENSE](LICENSE).

The name CommitJet is provisional and has not received trademark clearance. The app name and bundle identifier are defined in the Xcode project build settings and can be changed there.
