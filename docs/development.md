## Installation

```bash
# Install deps
pnpm install

# Build all packages
pnpm build

# Run tests
pnpm test

# Develop with live rebuilds
pnpm dev
```

---

## Release Process

We use [Changesets](https://github.com/changesets/changesets) to manage package versions, changelogs, and npm publishing.

### 1. Record a Change

Whenever you make a change that should result in a new release:

```bash
pnpm changeset
```

- Select which package(s) changed (`sonar-core`, `sonar-react`, or both).
- Choose the bump type:
    - `patch` – bug fix, backwards compatible
    - `minor` – new feature, backwards compatible
    - `major` – breaking change

- A markdown file will be created in `.changeset/` describing the change.

Commit this file along with your code.

---

### 2. Prepare a Release

When you’re ready to cut a release (usually after merging PRs with changesets), run the prepare script from the `main` branch:

```bash
pnpm prepare-release
```

This will:

- Pull the latest changes from `main`.
- Run `pnpm changeset version` to bump versions and update changelogs.
- Create a release branch (e.g., `release/20251216-143052`).
- Commit and push the changes.

Then create a PR to merge the release branch into `main`:

```bash
gh pr create --title 'chore: release' --body 'Release packages'
```

Note that we need to manually create the PR because our repository permissions currently block PR creation from Github actions.

---

### 3. Publishing (automated)

The GitHub Actions workflow runs on every `main` commit.
The publish step is idempotent - `changeset publish` checks npm and only publishes packages with versions not yet on the registry.
When you merge a release PR with version bumps, the new versions get published automatically.

---

## Summary

1. Use **`pnpm changeset`** in your PR to record what changed.
2. Run **`pnpm prepare-release`** to prepare a release PR.
3. Merge the release PR to automatically publish to npm.
