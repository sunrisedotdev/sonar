# Sonar Monorepo

This repo contains two packages:

- **`sonar-core`** – the core library for interacting with the Sonar API.
- **`sonar-react`** – React adapter built on top of `sonar`.

We use **pnpm workspaces** for dependency management and **Changesets** for versioning & publishing.

---

## Installation

You can install either package directly from npm:

```bash
# Core library (framework agnostic)
npm install @echoxyz/sonar-core

# React adapter (includes sonar as a dependency)
npm install @echoxyz/sonar-react
```

---

### Usage

#### Using `sonar` directly

```ts
import { tmp } from "sonar-core";

console.log(tmp);
```

#### Using `sonar-react`

```tsx
import { useSonar } from "sonar-react";

function App() {
  const tmp = useSonar();
  return <div>{tmp}</div>;
}
```

## Development

See [here](./docs/development.md).
