import { cp, rm, mkdir, writeFile } from "node:fs/promises";
import { execSync } from "node:child_process";
import { resolve } from "node:path";

const EVM_APPS = ["react-evm", "nextjs-evm"];
const SVM_APPS = ["react-svm", "nextjs-svm"];

async function generate(app) {
    const src = resolve(`examples/framework/${app}`);
    const out = resolve(`dist/${app}`);
    const sharedSrc = resolve(`examples/_shared`);

    await rm(out, { recursive: true, force: true });
    await mkdir(out, { recursive: true });

    await cp(src, out, { recursive: true });

    // Embed _shared/ui inside the dist app so the output repo is self-contained.
    // pnpm-workspace.yaml is rewritten to use a local path instead of ../../_shared/ui.
    await cp(`${sharedSrc}/ui`, `${out}/_shared/ui`, { recursive: true });
    await writeFile(
        `${out}/pnpm-workspace.yaml`,
        `packages:\n  - "./_shared/ui"\n`,
    );

    execSync(`pnpm --dir ${out} install`, { stdio: "inherit" });
    execSync(`pnpm --dir ${out} build`, { stdio: "inherit" });

    console.log(`✓ ${app}: built successfully → ${out}`);
}

const target = process.argv[2] ?? "all";
const includeSvm = process.argv.includes("--svm");
const targets = target === "all" ? (includeSvm ? [...EVM_APPS, ...SVM_APPS] : EVM_APPS) : [target];
for (const app of targets) await generate(app);
