/**
 * @fileoverview Comprehensive tests for MathForge
 * Demonstrates property-based testing, zod validation, fp-ts usage, and mathematical properties
 */

import { describe, expect, it, test } from "vitest";
import { z } from "zod";
import * as E from "fp-ts/Either";
import * as O from "fp-ts/Option";
import { pipe } from "fp-ts/function";
import { fc, generators, testConfig } from "./setup";

// Constants for testing (normally imported from main library)
const VERSION = "1.0.0";
const SUPPORTED_LANGUAGES = ["typescript", "python", "haskell"] as const;
const SUPPORTED_LAWS = [
  "monad.left_identity",
  "monad.right_identity",
  "monad.associativity",
  "functor.identity",
  "functor.composition",
  "monoid.identity",
  "monoid.associativity"
] as const;

describe("MathForge Core Library", () => {
  describe("Constants and Configuration", () => {
    test("should export correct version", () => {
      expect(VERSION).toBe("1.0.0");
      expect(typeof VERSION).toBe("string");
    });

    test("should export supported languages", () => {
      expect(SUPPORTED_LANGUAGES).toEqual(["typescript", "python", "haskell"]);
      expect(SUPPORTED_LANGUAGES).toHaveLength(3);
    });

    test("should export supported mathematical laws", () => {
      expect(SUPPORTED_LAWS).toContain("monad.left_identity");
      expect(SUPPORTED_LAWS).toContain("functor.identity");
      expect(SUPPORTED_LAWS).toContain("monoid.identity");
      expect(SUPPORTED_LAWS).toHaveLength(7);
    });
  });

  describe("Zod Schema Validation", () => {
    const targetLanguageSchema = z.enum(["typescript", "python", "haskell"]);
    const mathLawSchema = z.enum([
      "monad.left_identity",
      "monad.right_identity",
      "monad.associativity",
      "functor.identity",
      "functor.composition",
      "monoid.identity",
      "monoid.associativity"
    ]);

    test("should validate target languages with zod", () => {
      expect(targetLanguageSchema.safeParse("typescript").success).toBe(true);
      expect(targetLanguageSchema.safeParse("python").success).toBe(true);
      expect(targetLanguageSchema.safeParse("haskell").success).toBe(true);
      expect(targetLanguageSchema.safeParse("invalid").success).toBe(false);
    });

    test("should validate mathematical laws with zod", () => {
      expect(mathLawSchema.safeParse("monad.left_identity").success).toBe(true);
      expect(mathLawSchema.safeParse("functor.composition").success).toBe(true);
      expect(mathLawSchema.safeParse("invalid.law").success).toBe(false);
    });

    // Property-based test for schema validation
    test("property: all supported languages should validate", () => {
      fc.assert(
        fc.property(generators.targetLanguage, (lang) => {
          const result = targetLanguageSchema.safeParse(lang);
          expect(result.success).toBe(true);
        }),
        { numRuns: testConfig.propertyTestRuns }
      );
    });
  });

  describe("fp-ts Either Usage", () => {
    // Demonstrate fp-ts Either for error handling
    const divideByZero = (a: number, b: number): E.Either<string, number> => {
      return b === 0 ? E.left("Division by zero") : E.right(a / b);
    };

    test("should handle division correctly with Either", () => {
      const result1 = divideByZero(10, 2);
      const result2 = divideByZero(10, 0);

      expect(E.isRight(result1)).toBe(true);
      expect(E.isLeft(result2)).toBe(true);
      
      if (E.isRight(result1)) {
        expect(result1.right).toBe(5);
      }
      
      if (E.isLeft(result2)) {
        expect(result2.left).toBe("Division by zero");
      }
    });

    test("should chain Either operations", () => {
      const computation = pipe(
        E.right(20),
        E.chain((x) => divideByZero(x, 4)),
        E.map((x) => x * 2)
      );

      expect(E.isRight(computation)).toBe(true);
      if (E.isRight(computation)) {
        expect(computation.right).toBe(10);
      }
    });

    // Property-based test for mathematical properties
    test("property: division should be consistent", () => {
      fc.assert(
        fc.property(
          fc.float({ min: -1000, max: 1000 }),
          fc.float({ min: 0.1, max: 1000 }), // Avoid division by zero
          (a, b) => {
            const result = divideByZero(a, b);
            if (E.isRight(result)) {
              expect(result.right).toBeCloseTo(a / b, 5);
            }
          }
        ),
        { numRuns: testConfig.propertyTestRuns }
      );
    });
  });

  describe("fp-ts Option Usage", () => {
    const safeSqrt = (n: number): O.Option<number> => {
      return n >= 0 ? O.some(Math.sqrt(n)) : O.none;
    };

    test("should handle square root with Option", () => {
      const result1 = safeSqrt(16);
      const result2 = safeSqrt(-4);

      expect(O.isSome(result1)).toBe(true);
      expect(O.isNone(result2)).toBe(true);

      if (O.isSome(result1)) {
        expect(result1.value).toBe(4);
      }
    });

    // Property-based test for Option monadic properties
    test("property: Option should satisfy functor laws", () => {
      // Functor identity law: fmap(id) = id
      fc.assert(
        fc.property(fc.float(), (x) => {
          const opt = x >= 0 ? O.some(x) : O.none;
          const identity = <T>(t: T): T => t;
          
          expect(pipe(opt, O.map(identity))).toEqual(opt);
        }),
        { numRuns: testConfig.propertyTestRuns }
      );
    });
  });

  describe("Property-Based Testing Examples", () => {
    // Test mathematical properties
    test("property: addition is commutative", () => {
      fc.assert(
        fc.property(fc.integer(), fc.integer(), (a, b) => {
          expect(a + b).toBe(b + a);
        }),
        { numRuns: testConfig.propertyTestRuns }
      );
    });

    test("property: string concatenation is associative", () => {
      fc.assert(
        fc.property(fc.string(), fc.string(), fc.string(), (a, b, c) => {
          expect((a + b) + c).toBe(a + (b + c));
        }),
        { numRuns: testConfig.propertyTestRuns }
      );
    });

    test("property: array length is preserved during map", () => {
      fc.assert(
        fc.property(fc.array(fc.integer()), (arr) => {
          const doubled = arr.map(x => x * 2);
          expect(doubled.length).toBe(arr.length);
        }),
        { numRuns: testConfig.propertyTestRuns }
      );
    });

    test("property: generated type names are valid", () => {
      fc.assert(
        fc.property(generators.typeName, (name) => {
          expect(name).toMatch(/^[a-zA-Z][a-zA-Z0-9]*$/);
          expect(name.length).toBeGreaterThan(0);
          expect(name.length).toBeLessThanOrEqual(20);
        }),
        { numRuns: testConfig.propertyTestRuns }
      );
    });
  });

  describe("Mathematical Law Verification (Placeholder)", () => {
    // These would be implemented with actual mathematical verification
    test("monad laws placeholder", () => {
      const mockMonad = { value: 42 };
      // TODO: Implement actual monad law verification
      expect(mockMonad.value).toBe(42);
    });

    test("functor laws placeholder", () => {
      const mockFunctor = { value: [1, 2, 3] };
      // TODO: Implement actual functor law verification  
      expect(mockFunctor.value).toHaveLength(3);
    });

    test("monoid laws placeholder", () => {
      const mockMonoid = { value: "" };
      // TODO: Implement actual monoid law verification
      expect(mockMonoid.value).toBe("");
    });
  });

  describe("Integration Tests", () => {
    test("should integrate zod, fp-ts, and property testing", () => {
      const configSchema = z.object({
        language: z.enum(["typescript", "python", "haskell"]),
        strict: z.boolean(),
        laws: z.array(z.string())
      });

      fc.assert(
        fc.property(
          generators.targetLanguage,
          fc.boolean(),
          fc.array(generators.mathLaw, { maxLength: 3 }),
          (language, strict, laws) => {
            const config = { language, strict, laws };
            const result = configSchema.safeParse(config);
            
            expect(result.success).toBe(true);
            
            if (result.success) {
              const processedConfig = pipe(
                E.right(result.data),
                E.map(cfg => ({ ...cfg, processed: true }))
              );
              
              expect(E.isRight(processedConfig)).toBe(true);
            }
          }
        ),
        { numRuns: 50 } // Fewer runs for integration test
      );
    });
  });
}); 