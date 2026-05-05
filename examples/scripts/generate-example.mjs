import { cp, rm, mkdir } from "node:fs/promises";
import { execSync } from "node:child_process";
import { resolve } from "node:path";

const EVM_APPS = ["react-evm", "nextjs-evm"];
const SVM_APPS = ["react-svm", "nextjs-svm"];

async function generate(app) {
    const src = resolve(`examples/framework/${app}`);
    const out = resolve(`dist/${app}`);

    await rm(out, { recursive: true, force: true });
    await mkdir(out, { recursive: true });

    await cp(src, out, {
        recursive: true,
        filter: (source) => !source.includes("node_modules") && !source.includes(".next"),
    });

    // Seed .env from .env.example so Next.js prerendering has the required env vars.
    // push-example.sh uses `git add -A` which respects .gitignore, so .env won't be published.
    await cp(resolve(out, ".env.example"), resolve(out, ".env"));

    execSync(`pnpm --dir ${out} install`, { stdio: "inherit" });
    execSync(`pnpm --dir ${out} build`, { stdio: "inherit" });

    console.log(`✓ ${app}: built successfully → ${out}`);
}

const target = process.argv[2] ?? "all";
const includeSvm = process.argv.includes("--svm");
const targets = target === "all" ? (includeSvm ? [...EVM_APPS, ...SVM_APPS] : EVM_APPS) : [target];
for (const app of targets) await generate(app);
