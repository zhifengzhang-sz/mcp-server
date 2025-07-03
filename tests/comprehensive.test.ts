/**
 * @fileoverview Comprehensive tests for MathForge demonstrating best practices
 * Shows zod validation, fp-ts usage, property-based testing with fast-check
 */

import { describe, expect, test } from "vitest";
import { z } from "zod";
import * as E from "fp-ts/Either";
import * as O from "fp-ts/Option";
import { pipe } from "fp-ts/function";
import * as fc from "fast-check";

describe("MathForge Best Practices Demo", () => {
  describe("Zod Schema Validation", () => {
    const languageSchema = z.enum(["typescript", "python", "haskell"]);
    
    test("should validate supported languages", () => {
      expect(languageSchema.safeParse("typescript").success).toBe(true);
      expect(languageSchema.safeParse("python").success).toBe(true);
      expect(languageSchema.safeParse("haskell").success).toBe(true);
      expect(languageSchema.safeParse("invalid").success).toBe(false);
    });

    test("should validate complex objects", () => {
      const configSchema = z.object({
        language: languageSchema,
        strict: z.boolean(),
        version: z.string().min(1)
      });

      const validConfig = { language: "typescript", strict: true, version: "1.0.0" };
      const invalidConfig = { language: "invalid", strict: "not-boolean", version: "" };

      expect(configSchema.safeParse(validConfig).success).toBe(true);
      expect(configSchema.safeParse(invalidConfig).success).toBe(false);
    });
  });

  describe("fp-ts Either for Error Handling", () => {
    const safeDivide = (a: number, b: number): E.Either<string, number> => {
      return b === 0 ? E.left("Division by zero") : E.right(a / b);
    };

    test("should handle successful operations", () => {
      const result = safeDivide(10, 2);
      expect(E.isRight(result)).toBe(true);
      if (E.isRight(result)) {
        expect(result.right).toBe(5);
      }
    });

    test("should handle error cases", () => {
      const result = safeDivide(10, 0);
      expect(E.isLeft(result)).toBe(true);
      if (E.isLeft(result)) {
        expect(result.left).toBe("Division by zero");
      }
    });

    test("should chain operations", () => {
      const computation = pipe(
        E.right(20),
        E.chain((x) => safeDivide(x, 4)),
        E.map((x) => x * 2)
      );

      expect(E.isRight(computation)).toBe(true);
      if (E.isRight(computation)) {
        expect(computation.right).toBe(10);
      }
    });
  });

  describe("fp-ts Option for Null Safety", () => {
    const safeSqrt = (n: number): O.Option<number> => {
      return n >= 0 ? O.some(Math.sqrt(n)) : O.none;
    };

    test("should handle valid inputs", () => {
      const result = safeSqrt(16);
      expect(O.isSome(result)).toBe(true);
      if (O.isSome(result)) {
        expect(result.value).toBe(4);
      }
    });

    test("should handle invalid inputs", () => {
      const result = safeSqrt(-4);
      expect(O.isNone(result)).toBe(true);
    });

    test("should chain Option operations", () => {
      const computation = pipe(
        O.some(16),
        O.chain(safeSqrt),
        O.map((x) => x * 2)
      );

      expect(O.isSome(computation)).toBe(true);
      if (O.isSome(computation)) {
        expect(computation.value).toBe(8);
      }
    });
  });

  describe("Property-Based Testing with fast-check", () => {
    test("property: addition is commutative", () => {
      fc.assert(
        fc.property(fc.integer(), fc.integer(), (a, b) => {
          expect(a + b).toBe(b + a);
        }),
        { numRuns: 100 }
      );
    });

    test("property: multiplication by zero", () => {
      fc.assert(
        fc.property(fc.integer(), (a) => {
          expect(a * 0).toBe(0);
        }),
        { numRuns: 50 }
      );
    });

    test("property: array length after map", () => {
      fc.assert(
        fc.property(fc.array(fc.integer()), (arr) => {
          const doubled = arr.map(x => x * 2);
          expect(doubled.length).toBe(arr.length);
        }),
        { numRuns: 100 }
      );
    });

    test("property: string concatenation associativity", () => {
      fc.assert(
        fc.property(fc.string(), fc.string(), fc.string(), (a, b, c) => {
          expect((a + b) + c).toBe(a + (b + c));
        }),
        { numRuns: 100 }
      );
    });
  });

  describe("Integration: Zod + fp-ts + fast-check", () => {
    const userSchema = z.object({
      name: z.string().min(1),
      age: z.number().min(0).max(150),
      email: z.string().email()
    });

    const validateUser = (data: unknown): E.Either<string, z.infer<typeof userSchema>> => {
      const result = userSchema.safeParse(data);
      return result.success 
        ? E.right(result.data)
        : E.left(`Validation failed: ${result.error.issues.map(i => i.message).join(", ")}`);
    };

    test("should validate and process user data", () => {
      const validUser = { name: "Alice", age: 30, email: "alice@example.com" };
      const result = validateUser(validUser);

      expect(E.isRight(result)).toBe(true);
      if (E.isRight(result)) {
        expect(result.right.name).toBe("Alice");
      }
    });

    test("should handle invalid user data", () => {
      const invalidUser = { name: "", age: -5, email: "invalid-email" };
      const result = validateUser(invalidUser);

      expect(E.isLeft(result)).toBe(true);
    });

    test("property: valid users should always validate", () => {
      const validUserGenerator = fc.record({
        name: fc.string({ minLength: 1, maxLength: 50 }),
        age: fc.integer({ min: 0, max: 150 }),
        email: fc.emailAddress()
      });

      fc.assert(
        fc.property(validUserGenerator, (user) => {
          const result = validateUser(user);
          expect(E.isRight(result)).toBe(true);
        }),
        { numRuns: 50 }
      );
    });
  });

  describe("Mathematical Properties", () => {
    test("monad identity law simulation", () => {
      // Left identity: return a >>= f === f a
      const f = (x: number): E.Either<string, number> => E.right(x * 2);
      const a = 5;

      const left = pipe(E.right(a), E.chain(f));
      const right = f(a);

      expect(left).toEqual(right);
    });

    test("functor identity law simulation", () => {
      // fmap id = id
      const identity = <T>(x: T): T => x;
      const option = O.some(42);

      const mapped = pipe(option, O.map(identity));
      expect(mapped).toEqual(option);
    });

    test("monoid associativity simulation", () => {
      // (a + b) + c = a + (b + c)
      fc.assert(
        fc.property(fc.string(), fc.string(), fc.string(), (a, b, c) => {
          expect((a + b) + c).toBe(a + (b + c));
        }),
        { numRuns: 100 }
      );
    });
  });
}); 