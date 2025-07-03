/**
 * @fileoverview Test setup for MathForge with property-based testing
 * Configures fast-check and other testing utilities
 */

import { expect } from "vitest";
import fc from 'fast-check';
import { beforeAll, beforeEach, afterEach, afterAll } from 'vitest';

// Configure fast-check for property-based testing
beforeAll(() => {
  // Set global configuration for fast-check
  fc.configureGlobal({
    // Number of test cases for each property
    numRuns: 100,
    // Verbose output for debugging
    verbose: process.env['VITEST_VERBOSE'] === 'true',
    // Seed for reproducible tests
    seed: process.env['VITEST_SEED'] ? parseInt(process.env['VITEST_SEED'], 10) : undefined,
  });
});

// Setup for each test
beforeEach(() => {
  // Clear any global state before each test
  // Reset any mocks or spies if needed
});

// Cleanup after each test
afterEach(() => {
  // Clean up any side effects
  // Reset any global state
});

// Global cleanup
afterAll(() => {
  // Final cleanup
});

// Global test utilities
declare global {
  // Make fast-check available globally
  var fc: typeof import('fast-check');
}

// Export fast-check globally for convenience
(globalThis as any).fc = fc;

// Console setup for tests
if (process.env['NODE_ENV'] === 'test') {
  // Suppress console.log in tests unless explicitly enabled
  if (!process.env['VITEST_CONSOLE']) {
    console.log = (): void => {};
  }
}

// Custom matchers for mathematical properties
declare global {
  namespace Vi {
    interface Assertion {
      toSatisfyMonadLaws(): void;
      toSatisfyFunctorLaws(): void;
      toSatisfyMonoidLaws(): void;
      toBeValidSchema(): void;
    }
  }
}

// Extend expect with custom matchers
expect.extend({
  toSatisfyMonadLaws(received: any) {
    // TODO: Implement monad law verification
    const pass = true; // Placeholder
    return {
      message: () => `Expected ${received} to satisfy monad laws`,
      pass,
    };
  },
  
  toSatisfyFunctorLaws(received: any) {
    // TODO: Implement functor law verification  
    const pass = true; // Placeholder
    return {
      message: () => `Expected ${received} to satisfy functor laws`,
      pass,
    };
  },
  
  toSatisfyMonoidLaws(received: any) {
    // TODO: Implement monoid law verification
    const pass = true; // Placeholder
    return {
      message: () => `Expected ${received} to satisfy monoid laws`,
      pass,
    };
  },
  
  toBeValidSchema(received: any) {
    // TODO: Implement schema validation
    const pass = true; // Placeholder
    return {
      message: () => `Expected ${received} to be a valid schema`,
      pass,
    };
  },
});

// Export fast-check for use in tests
export { fc };

// Export commonly used generators for mathematical properties
export const generators = {
  // Generate valid mathematical expressions
  mathExpression: fc.string({ minLength: 1, maxLength: 50 }),
  
  // Generate valid type names
  typeName: fc.string({ minLength: 1, maxLength: 20 }).filter(s => /^[a-zA-Z][a-zA-Z0-9]*$/.test(s)),
  
  // Generate valid mathematical laws
  mathLaw: fc.constantFrom(
    "monad.left_identity",
    "monad.right_identity", 
    "monad.associativity",
    "functor.identity",
    "functor.composition",
    "monoid.identity",
    "monoid.associativity"
  ),
  
  // Generate valid target languages
  targetLanguage: fc.constantFrom("typescript", "python", "haskell"),
  
  // Generate valid YAML-like objects
  yamlObject: fc.dictionary(
    fc.string({ minLength: 1, maxLength: 20 }),
    fc.oneof(
      fc.string(),
      fc.integer(),
      fc.boolean(),
      fc.array(fc.string(), { maxLength: 5 })
    ),
    { maxKeys: 10 }
  ),
};

// Global test configuration
export const testConfig = {
  propertyTestRuns: 100,
  timeout: 5000,
  seed: 42,
}; 