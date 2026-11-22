# CommitJet

A small native macOS menu bar helper for making local Git commits. CommitJet can ask a local Ollama server to suggest a commit subject, but manual commits work without Ollama.

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

The app appears in the menu bar. Choose a local Git repository to see its current branch, changed-file count, and an expandable, scrollable list of changed paths and statuses. Select files and use **Stage selected** or **Unstage selected** to manage the Git staging area. Commits and AI message suggestions use staged changes only. Select the branch name to search and switch between local branches. Git keeps compatible working-tree changes and blocks a switch if it would overwrite them. Enter a commit message, then select **Commit**. On the first commit in each repository, confirm that the staged changes should be committed. Select **Don't show again** in that warning to suppress it for future commits; you can restore it in Settings.

To start CommitJet automatically when you sign in to your Mac, enable **Launch at login** in Settings. macOS may ask you to allow it under **System Settings → General → Login Items**.

## Ollama

Start Ollama locally, install a model (for example `ollama pull qwen2.5-coder`), then open CommitJet's Settings. Keep the server address at `http://localhost:11434`, load models, and select one. Choose English or German as the commit message language and select a short, normal, or detailed suggestion. Short generates one subject line of at most 50 characters; normal adds one body sentence of at most 20 words; detailed adds 2–3 body sentences of at most 45 words. The selected length is shown beside the Sparkles button and in the ready-to-review status. You can edit the suggestion before committing. In-app Help explains repository selection, message generation, privacy, and confirmation settings.

AI generation is optional and only runs after clicking Sparkles. A remote server address triggers a privacy notice; the diff is sent only to that configured endpoint. Requests have a 45 second timeout and diffs larger than 150 KB are refused.

## Privacy

CommitJet has no telemetry, accounts, or cloud integration. It does not upload Git data automatically. Repository content is not written to app logs. Git diff content is treated as untrusted prompt data and cannot trigger app actions.

## Git behavior and limitations

- CommitJet creates local commits, switches between existing local branches, and pushes commits to a configured remote when you select **Sync changes**. For a branch without an upstream, it publishes the branch to the first configured remote. If the local branch is behind its upstream, pushing is blocked and the remote changes must be pulled with another Git client first.
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
