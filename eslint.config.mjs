import js from "@eslint/js";
import globals from "globals";
import tseslint from "typescript-eslint";
import pluginReact from "eslint-plugin-react";
import { defineConfig } from "eslint/config";

export default defineConfig([
    {
        // DOLATER: fix eslint violations in framework dirs and remove this ignore
        ignores: ["**/node_modules/**", "**/dist/**", "contracts/**", "examples/framework/**", "examples/shared/**"],
    },
    {
        files: ["**/*.{js,mjs,cjs,ts,mts,cts,jsx,tsx}"],
        plugins: { js },
        extends: ["js/recommended"],
        languageOptions: { globals: globals.browser },
    },
    {
        files: ["examples/scripts/**"],
        languageOptions: { globals: globals.node },
    },
    tseslint.configs.recommended,
    pluginReact.configs.flat.recommended,
]);
