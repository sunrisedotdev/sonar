import { cp, rm, mkdir, readFile, writeFile, readdir } from "node:fs/promises";
import { execSync } from "node:child_process";
import { resolve, join, extname } from "node:path";

const GITIGNORE = `# dependencies
node_modules

# build output
dist
build
out
.next

# env files
.env*
!.env.example

# typescript
*.tsbuildinfo
next-env.d.ts

# editor
.DS_Store
*.pem

# debug logs
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*

# deployment
.vercel
`;

const EVM_APPS = ["react-evm", "nextjs-evm"];
const SVM_APPS = ["react-svm", "nextjs-svm"];

async function walkAndRewrite(dir, extensions, replacements) {
    const entries = await readdir(dir, { withFileTypes: true });
    for (const entry of entries) {
        const full = join(dir, entry.name);
        if (entry.isDirectory()) {
            await walkAndRewrite(full, extensions, replacements);
        } else if (extensions.includes(extname(entry.name))) {
            let content = await readFile(full, "utf8");
            for (const [from, to] of replacements) content = content.replaceAll(from, to);
            await writeFile(full, content);
        }
    }
}

async function generate(app) {
    const src = resolve(`examples/framework/${app}`);
    const out = resolve(`dist/${app}`);

    await rm(out, { recursive: true, force: true });
    await mkdir(out, { recursive: true });

    await cp(src, out, {
        recursive: true,
        filter: (source) => !source.includes("node_modules") && !source.includes(".next"),
    });

    await writeFile(resolve(out, ".gitignore"), GITIGNORE);

    // Merge each shared subdirectory (components/, lib/, …) directly into src/ so
    // the standalone repo needs no special path alias — @/ covers everything.
    for (const name of await readdir(resolve("examples/shared"))) {
        await cp(resolve("examples/shared", name), resolve(out, "src", name), { recursive: true });
    }

    // Rewrite @shared/ → @/ in all source files now that the code lives under src/.
    await walkAndRewrite(resolve(out, "src"), [".ts", ".tsx"], [["@shared/", "@/"]]);

    // Drop the now-unused @shared alias lines from tsconfig.json and vite.config.ts.
    for (const file of ["tsconfig.json", "vite.config.ts"]) {
        const filePath = resolve(out, file);
        try {
            const content = await readFile(filePath, "utf8");
            const cleaned = content
                .split("\n")
                .filter((line) => !line.includes('"@shared/*"') && !line.includes('"@shared":'))
                .join("\n");
            await writeFile(filePath, cleaned);
        } catch {
            // file may not exist (e.g. Next.js apps have no vite.config.ts)
        }
    }

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
