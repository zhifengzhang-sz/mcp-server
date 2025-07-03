/// <reference types="vitest" />
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // Test environment
    environment: "node",
    globals: true,
    
    // Coverage configuration
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html"],
      reportsDirectory: "./coverage",
      thresholds: {
        statements: 90,
        branches: 85,
        functions: 90,
        lines: 90,
      },
      exclude: [
        "node_modules/**",
        "dist/**",
        "coverage/**",
        "**/*.config.{js,ts}",
        "**/*.test.{js,ts}",
        "**/*.spec.{js,ts}",
        "demo-agent.ts",
      ],
    },
    
    // Test file patterns
    include: [
      "tests/**/*.{test,spec}.{js,ts}",
      "**/__tests__/**/*.{js,ts}",
    ],
    exclude: [
      "node_modules/**",
      "dist/**",
      "coverage/**",
    ],
    
    // Timeouts
    testTimeout: 10000,
    hookTimeout: 10000,
    
    // Watch mode
    watch: true,
    
    // Performance
    pool: "threads",
    poolOptions: {
      threads: {
        minThreads: 1,
        maxThreads: 4,
      }
    },
    
    // Property-based testing with fast-check
    setupFiles: ["./tests/setup.ts"]
  },
  
  // Path resolution for imports
  resolve: {
    alias: {
      "@": "./",
      "@core": "./core",
      "@types": "./types",
      "@cli": "./cli",
      "@agent": "./agent"
    }
  }
}); 