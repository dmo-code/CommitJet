# CommitJet

A small native macOS menu bar helper for making local Git commits. CommitJet can ask a local Ollama server to suggest a commit subject, but manual commits work without Ollama.

## Requirements

- macOS 13 or later
- Xcode 27.2 or a compatible recent Xcode with Swift 6
- Git available at `/usr/bin/git`
- Ollama is optional; the default server is `http://localhost:11434`

The app uses `MenuBarExtra` and has no Dock icon or persistent main window. The deployment target is macOS 13, where SwiftUI's menu bar extra is available.

## Build and run

1. Open `CommitJet.xcodeproj` in Xcode.
2. Select the **CommitJet** scheme and run it, or build with:

   ```sh
   xcodebuild -project CommitJet.xcodeproj -scheme CommitJet -destination 'platform=macOS' -derivedDataPath /tmp/CommitJetDerived CODE_SIGNING_ALLOWED=NO build
   ```

The app appears in the menu bar. Choose a local repository folder to see its branch, changed-file count, and an expandable, scrollable list of changed paths and statuses. Enter a commit message, then select **Commit**. On the first commit in each repository, confirm that all non-ignored changes (including staged and new files) should be included.

## Ollama

Start Ollama locally, install a model (for example `ollama pull qwen2.5-coder`), then open CommitJet's Settings. Keep the server address at `http://localhost:11434`, load models, and select one. Choose English or German as the commit message language. The Sparkles button requests a concise Conventional Commit subject. You can edit the suggestion before committing.

AI generation is optional and only runs after clicking Sparkles. A remote server address triggers a privacy notice; the diff is sent only to that configured endpoint. Requests have a 45 second timeout and diffs larger than 150 KB are refused.

## Privacy

CommitJet has no telemetry, accounts, or cloud integration. It does not upload Git data automatically. Repository content is not written to app logs. Git diff content is treated as untrusted prompt data and cannot trigger app actions.

## Git behavior and limitations

- CommitJet only creates local commits. It does not push, fetch, pull, merge, rebase, or manage branches.
- A commit includes all non-ignored working tree changes, including changes already staged, using Git's normal ignore rules.
- The first commit in each repository requires explicit confirmation. Changed submodules, unresolved conflicts, and active merge/rebase/cherry-pick/revert/bisect states are refused.
- The AI suggestion is built from a temporary Git index so generating it does not alter the repository index. Before committing, CommitJet checks that the commit candidate still matches the analyzed diff.
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
