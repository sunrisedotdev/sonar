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

- Select which package(s) changed (`sonar`, `sonar-react`, or both).
- Choose the bump type:
  - `patch` – bug fix, backwards compatible
  - `minor` – new feature, backwards compatible
  - `major` – breaking change

- A markdown file will be created in `.changeset/` describing the change.

Commit this file along with your code.

---

### 2. Versioning

When you’re ready to cut a release (usually after merging PRs with changesets):

```bash
pnpm version-packages
```

This will:

- Bump versions of changed packages.
- Update `CHANGELOG.md` files.
- Update inter-package dependencies (`workspace:*`) to match new versions.

Commit these changes:

```bash
git add .
git commit -m "chore: version packages"
```

---

### 3. Publishing

To publish to npm:

```bash
pnpm release
```

This runs `changeset publish`, which:

- Publishes new versions of changed packages to npm.
- Skips unchanged packages.

---

### 4. CI/CD Auto-Publishing

We also have a GitHub Actions workflow (`.github/workflows/release.yml`) that publishes automatically:

- On every push to `main`, if there are unpublished changesets, the workflow will version & publish.
- Uses the `NPM_TOKEN` secret for authentication.

This means:

- Engineers only need to run `pnpm changeset` in their PRs.
- Publishing is handled by CI after merge.

---

## Summary

- Use **`pnpm changeset`** in your PR to record what changed.
- CI/CD takes care of versioning & publishing when the PR merges.
- No manual npm publish needed.
