export type FetchLike = (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;

export function createJsonFetcher(opts?: { onUnauthorized?: () => void }): FetchLike {
    return async (input: RequestInfo | URL, init?: RequestInit) => {
        const resp = await fetch(input, init);
        if (resp.status === 401) {
            if (opts?.onUnauthorized) {
                try {
                    opts.onUnauthorized();
                } catch {}
            }
        }

        return new Proxy(resp, {
            get(target, prop) {
                const original = (target as any)[prop];
                if (typeof original === "function") {
                    return original.bind(target);
                }
                if (prop === "json") {
                    if (!target.ok) {
                        return original;
                    }
                    return async () => {
                        const body = await target.text();
                        try {
                            return JSON.parse(body);
                        } catch (e) {
                            let msg = String(e);
                            msg += `: the original request returned ${target.status}: ${body}`;
                            throw new Error(msg);
                        }
                    };
                }
                return original;
            },
        });
    };
}

export class APIError extends Error {
    public readonly status: number;
    public readonly code?: string;
    public readonly details?: unknown;

    constructor(status: number, message: string, code?: string, details?: unknown) {
        super(message);
        Object.setPrototypeOf(this, new.target.prototype);
        this.name = "APIError";
        this.status = status;
        this.code = code;
        this.details = details;
    }
}
