import "@testing-library/jest-dom/vitest";
import { cleanup, configure } from "@testing-library/react";
import { afterEach, beforeEach, vi } from "vitest";

// Whole-page renders are slow when vitest runs every file in parallel; the 1 s
// default for findBy*/waitFor made the cold first render flaky. A missing
// element still fails, just after 5 s.
configure({ asyncUtilTimeout: 5000 });

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
