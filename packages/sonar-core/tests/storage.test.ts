import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { createMemoryStorage, createWebStorage, type StorageLike } from "../src/storage";

function runCommonStorageSuite(factory: () => StorageLike) {
    it("returns null for missing keys", () => {
        const s = factory();
        expect(s.getItem("missing")).toBeNull();
    });

    it("sets and gets values", () => {
        const s = factory();
        s.setItem("k", "v");
        expect(s.getItem("k")).toBe("v");
    });

    it("removes values", () => {
        const s = factory();
        s.setItem("k", "v");
        s.removeItem("k");
        expect(s.getItem("k")).toBeNull();
    });
}

describe("createMemoryStorage", () => {
    const factory = () => createMemoryStorage();
    runCommonStorageSuite(factory);
});

describe("createWebStorage", () => {
    const originalWindow = globalThis.window as any;
    let getItemSpy: ReturnType<typeof vi.fn> & ((key: string) => string | null);
    let setItemSpy: ReturnType<typeof vi.fn> & ((key: string, value: string) => void);
    let removeItemSpy: ReturnType<typeof vi.fn> & ((key: string) => void);

    beforeEach(() => {
        getItemSpy = vi.fn((key: string) => null);
        setItemSpy = vi.fn((key: string, _value: string) => undefined);
        removeItemSpy = vi.fn((key: string) => undefined);
        (globalThis as any).window = {
            localStorage: {
                getItem: getItemSpy,
                setItem: setItemSpy,
                removeItem: removeItemSpy,
            },
        };
    });

    afterEach(() => {
        (globalThis as any).window = originalWindow;
        vi.restoreAllMocks();
    });

    it("uses window.localStorage when window is defined", () => {
        const s = createWebStorage();
        expect(s.getItem("k")).toBeNull();
        expect(getItemSpy).toHaveBeenCalledWith("k");

        s.setItem("k", "v");
        expect(setItemSpy).toHaveBeenCalledWith("k", "v");

        s.removeItem("k");
        expect(removeItemSpy).toHaveBeenCalledWith("k");
    });

    it("swallows localStorage errors and returns null on get", () => {
        getItemSpy.mockImplementation(() => {
            throw new Error("quota");
        });
        const s = createWebStorage();
        expect(s.getItem("x")).toBeNull();
    });

    it("swallows errors on set and remove", () => {
        setItemSpy.mockImplementation(() => {
            throw new Error("readonly");
        });
        removeItemSpy.mockImplementation(() => {
            throw new Error("readonly");
        });
        const s = createWebStorage();
        s.setItem("a", "b");
        s.removeItem("a");
        // no throw
    });

    it("falls back to memory storage when window is undefined", () => {
        (globalThis as any).window = undefined;
        const s = createWebStorage();
        s.setItem("k", "v");
        expect(s.getItem("k")).toBe("v");
        s.removeItem("k");
        expect(s.getItem("k")).toBeNull();
    });
});
