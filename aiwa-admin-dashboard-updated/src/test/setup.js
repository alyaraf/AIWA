import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import { afterEach, beforeEach, vi } from "vitest";

// React Testing Library recommends unmounting between tests so state from one
// test can't leak into another.
afterEach(() => {
  cleanup();
});

// Each test gets a fresh localStorage. Otherwise a token stored by one test
// would silently authenticate the next one.
beforeEach(() => {
  window.localStorage.clear();
  vi.restoreAllMocks();
});
