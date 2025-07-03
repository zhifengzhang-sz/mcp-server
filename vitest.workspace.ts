import { defineWorkspace } from "vitest/config";

export default defineWorkspace([
  {
    test: {
      name: "mathforge",
      environment: "node",
      globals: true,
      include: ["./tests/**/*.test.ts", "./tests/**/*.spec.ts"],
      exclude: ["./node_modules/**", "./dist/**"],
      isolate: true,
      pool: "forks"
    }
  }
]); 