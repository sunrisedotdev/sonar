# Example Apps

Sonar ships standalone example apps for each supported framework and chain type. This directory contains the source apps and the tooling to publish them.

## Structure

```
examples/
  framework/          # Source apps (one per framework/chain combination)
    react-evm/        # React + EVM (published to sonar-example-react)
    nextjs-evm/       # Next.js + EVM (published to sonar-example-nextjs)
    react-svm/        # React + SVM (published to sonar-example-react-svm)
    nextjs-svm/       # Next.js + SVM (published to sonar-example-nextjs-svm)
  scripts/
    generate-example.mjs   # Builds a framework app into dist/
    push-example.sh        # Pushes a built app to its output repo as a PR
    release-examples.sh    # Orchestrates generate + push for all apps
```

Each `framework/<app>/` dir is a verbatim copy of its corresponding output repo. Changes are made here, then published via the release script.

## Output repos

| App          | Repo                                                                                  |
| ------------ | ------------------------------------------------------------------------------------- |
| `react-evm`  | [sonar-example-react](https://github.com/sunrisedotdev/sonar-example-react)           |
| `nextjs-evm` | [sonar-example-nextjs](https://github.com/sunrisedotdev/sonar-example-nextjs)         |
| `react-svm`  | [sonar-example-react-svm](https://github.com/sunrisedotdev/sonar-example-react-svm)   |
| `nextjs-svm` | [sonar-example-nextjs-svm](https://github.com/sunrisedotdev/sonar-example-nextjs-svm) |

## Releasing

Run from the repo root:

```bash
# EVM only
bash examples/scripts/release-examples.sh

# EVM + SVM (once SVM framework dirs exist)
bash examples/scripts/release-examples.sh --svm
```

The script will:

1. Copy each framework app into `dist/<app>/`, install, and build it
2. Clone the output repo, sync the built app into it, and open a PR on `chore/generated-update`
3. Print a ready-to-paste Slack message with links to all opened PRs

**Prerequisite:** `gh auth login` — the script uses your existing GitHub CLI auth, no PAT or secrets needed.

## CI

`.github/workflows/lint-examples.yml` runs lint and build for each EVM framework app on PRs that touch `examples/`. SVM apps are excluded until their framework dirs exist.
