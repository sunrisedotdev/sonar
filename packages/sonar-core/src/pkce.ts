function base64UrlEncode(bytes: Uint8Array): string {
    // PKCE spec (RFC 7636) requires base64url encoding *without* padding.
    let binary = "";
    for (let i = 0; i < bytes.byteLength; i++) {
        binary += String.fromCharCode(bytes[i]);
    }
    // Remove padding (=) as required by PKCE
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function generateCodeVerifier(): string {
    // 32 bytes entropy -> 43 char URL-safe base64, within PKCE spec range (43-128)
    const bytes = new Uint8Array(32);
    if (typeof crypto === "undefined" || typeof crypto.getRandomValues !== "function") {
        throw new Error("crypto.getRandomValues is not available");
    }
    crypto.getRandomValues(bytes);
    return base64UrlEncode(bytes);
}

async function generateCodeChallenge(codeVerifier: string): Promise<string> {
    if (typeof crypto !== "undefined" && crypto.subtle && typeof TextEncoder !== "undefined") {
        const data = new TextEncoder().encode(codeVerifier);
        const hash = await crypto.subtle.digest("SHA-256", data);
        return base64UrlEncode(new Uint8Array(hash));
    }
    // Fallback: not ideal without subtle crypto, but environments without it are unlikely browsers.
    // Consumers on Node should polyfill.
    throw new Error("SubtleCrypto not available to compute code challenge");
}

type PKCEParams = {
    codeVerifier: string;
    codeChallenge: string;
    state: string;
};

export async function generatePKCEParams(): Promise<PKCEParams> {
    const codeVerifier = generateCodeVerifier();
    const codeChallenge = await generateCodeChallenge(codeVerifier);
    const state = crypto.randomUUID();
    return { codeVerifier, codeChallenge, state };
}
