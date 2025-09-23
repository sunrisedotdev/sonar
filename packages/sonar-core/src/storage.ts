export interface StorageLike {
    getItem(key: string): string | null | undefined;
    setItem(key: string, value: string): void;
    removeItem(key: string): void;
}

export function createMemoryStorage(): StorageLike {
    const map = new Map<string, string>();
    return {
        getItem(key) {
            return map.has(key) ? map.get(key)! : null;
        },
        setItem(key, value) {
            map.set(key, value);
        },
        removeItem(key) {
            map.delete(key);
        },
    };
}

export function createWebStorage(): StorageLike {
    if (typeof window === "undefined") {
        return createMemoryStorage();
    }
    const ls = window.localStorage;
    return {
        getItem(key) {
            try {
                return ls.getItem(key);
            } catch {
                return null;
            }
        },
        setItem(key, value) {
            try {
                ls.setItem(key, value);
            } catch {
                // ignore quota or privacy mode errors
            }
        },
        removeItem(key) {
            try {
                ls.removeItem(key);
            } catch {
                // ignore
            }
        },
    };
}
