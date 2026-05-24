// MARK: - BASEvolutionaryMutator
// chapter 九百四十六 / M3435
//
// User directive 「进化 算法 加强 程序化生成」 — input mutation
// engine for evolutionary fuzz testing。 Given a seed input,
// produces N mutated children;test runner picks「fittest」 children
// (e.g. ones that triggered new code paths / crashes / slow runs)
// to seed next generation。 Classic genetic algorithm shape。
//
// Compared to plain random fuzzing,evolutionary mutation
// converges on bug-triggering inputs faster because:
//   - Successful mutations (those that found something) propagate
//   - Failed mutations don't dominate the search
//
// This is the substrate's first GA infrastructure。 Per ch 862 RL
// audit DECLINE,we don't add a full RL learner — but a simple
// mutation+selection loop is appropriate for test input search
// (no reward function ambiguity here:fitness = bug found OR
// new coverage hit)。

import Foundation

/// Bit-level mutation of an arbitrary value via its raw bytes。
/// Caller provides byte buffer + mutator picks 1-N bits/bytes to
/// flip。 Returns a new buffer of same size with N mutations applied。
public enum BASByteMutator {
    /// Flip a single random bit。
    public static func bitFlip(
        _ bytes: [UInt8],
        rng: inout BASFuzzRng
    ) -> [UInt8] {
        guard !bytes.isEmpty else { return bytes }
        var out = bytes
        let byteIdx = rng.nextInt(upTo: out.count)
        let bitIdx = rng.nextInt(upTo: 8)
        out[byteIdx] ^= UInt8(1 << bitIdx)
        return out
    }

    /// Replace random byte with random value (full-byte mutation)。
    public static func byteReplace(
        _ bytes: [UInt8],
        rng: inout BASFuzzRng
    ) -> [UInt8] {
        guard !bytes.isEmpty else { return bytes }
        var out = bytes
        let idx = rng.nextInt(upTo: out.count)
        out[idx] = UInt8(rng.nextInt(upTo: 256))
        return out
    }

    /// Insert a random byte at random position (length grows by 1)。
    public static func byteInsert(
        _ bytes: [UInt8],
        rng: inout BASFuzzRng
    ) -> [UInt8] {
        var out = bytes
        let idx = rng.nextInt(upTo: out.count + 1)
        out.insert(UInt8(rng.nextInt(upTo: 256)), at: idx)
        return out
    }

    /// Delete a random byte (length shrinks by 1)。
    public static func byteDelete(
        _ bytes: [UInt8],
        rng: inout BASFuzzRng
    ) -> [UInt8] {
        guard bytes.count > 1 else { return bytes }
        var out = bytes
        out.remove(at: rng.nextInt(upTo: out.count))
        return out
    }

    /// Apply a random mutation (1 of 4 strategies)。
    public static func mutate(
        _ bytes: [UInt8],
        rng: inout BASFuzzRng
    ) -> [UInt8] {
        switch rng.nextInt(upTo: 4) {
        case 0: return bitFlip(bytes, rng: &rng)
        case 1: return byteReplace(bytes, rng: &rng)
        case 2: return byteInsert(bytes, rng: &rng)
        default: return byteDelete(bytes, rng: &rng)
        }
    }
}

/// Float-vector mutator for numeric inputs (mamba/retrieval/MPS)。
public enum BASFloatVectorMutator {
    /// Add Gaussian-ish noise to each element (uniform-distributed
    /// approximation;avoids needing Foundation random)。
    public static func addNoise(
        _ values: [Float],
        magnitude: Float = 0.1,
        rng: inout BASFuzzRng
    ) -> [Float] {
        return values.map { v in
            v + rng.nextFloat(in: -magnitude...magnitude)
        }
    }

    /// Scale all values by a random factor in [0.5, 2.0]。
    public static func scale(
        _ values: [Float],
        rng: inout BASFuzzRng
    ) -> [Float] {
        let factor = rng.nextFloat(in: 0.5...2.0)
        return values.map { $0 * factor }
    }

    /// Inject NaN/Inf/zero at a random index — boundary edge cases。
    public static func injectExtreme(
        _ values: [Float],
        rng: inout BASFuzzRng
    ) -> [Float] {
        guard !values.isEmpty else { return values }
        var out = values
        let extremes: [Float] = [
            .nan, .infinity, -.infinity,
            0.0, -0.0, .greatestFiniteMagnitude,
            -.greatestFiniteMagnitude,
        ]
        let idx = rng.nextInt(upTo: out.count)
        out[idx] = rng.pick(extremes)
        return out
    }

    /// Apply a random mutation (1 of 3 strategies)。
    public static func mutate(
        _ values: [Float],
        rng: inout BASFuzzRng
    ) -> [Float] {
        switch rng.nextInt(upTo: 3) {
        case 0: return addNoise(
            values, magnitude: rng.nextFloat(in: 0.01...0.5),
            rng: &rng)
        case 1: return scale(values, rng: &rng)
        default: return injectExtreme(values, rng: &rng)
        }
    }
}

/// String mutator for prompt / actor / session id fuzzing。
public enum BASStringMutator {
    /// Insert special chars at random position — test JSON escape /
    /// SQL injection / UTF-8 boundary handling。
    public static func injectSpecial(
        _ s: String,
        rng: inout BASFuzzRng
    ) -> String {
        let specials = [
            "\"", "\\", "\n", "\r", "\t", "\0",
            "';--", "\u{1F4A9}",   // pile of poo (emoji)
            "\u{0000}",  // NUL
            "\u{FFFD}",  // replacement char
        ]
        let pos = s.isEmpty
            ? s.startIndex
            : s.index(s.startIndex,
                      offsetBy: rng.nextInt(upTo: s.count + 1),
                      limitedBy: s.endIndex) ?? s.startIndex
        var out = s
        out.insert(contentsOf: rng.pick(specials), at: pos)
        return out
    }

    /// Repeat the string N times to test length-cap behavior。
    /// chapter 九百四十八 — iPhone Air simulator jetsam fix:
    /// reduced max 100 → 10 to fit in iOS app memory ceiling
    /// (combined with evolutionary search's 2 children + 1 gen,
    /// keeps total mutated-string footprint under ~100KB)。
    /// Boundary cases (very long strings) still tested in
    /// `boundary()` (10K char) which is bounded - here we limit
    /// the multiplier。
    public static func repeating(
        _ s: String,
        rng: inout BASFuzzRng
    ) -> String {
        let n = rng.nextInt(in: 1...10)
        return String(repeating: s, count: n)
    }

    /// Empty / single-char / multi-char boundary。
    public static func boundary(
        rng: inout BASFuzzRng
    ) -> String {
        let choices = [
            "",                        // empty (legacy ch 915 fix)
            "a",                       // single char
            String(repeating: "x", count: 100),  // medium
            String(repeating: "y", count: 10_000), // large
            "\u{1F4A9}",               // emoji (multi-byte UTF-8)
        ]
        return rng.pick(choices)
    }

    /// Apply random mutation (1 of 3)。
    public static func mutate(
        _ s: String,
        rng: inout BASFuzzRng
    ) -> String {
        switch rng.nextInt(upTo: 3) {
        case 0: return injectSpecial(s, rng: &rng)
        case 1: return repeating(s, rng: &rng)
        default: return boundary(rng: &rng)
        }
    }
}

/// Evolutionary loop — given a seed input and a fitness function,
/// runs N generations producing G children each,keeping the best
/// K survivors per generation。 Returns the best individual found
/// across all generations。
///
/// Fitness function semantics:HIGHER = BETTER。 Common shapes:
///   - 1.0 if a new code path / assertion fires,0.0 otherwise
///   - measured runtime (slow inputs reveal perf gaps)
///   - bit count of distinct outputs seen
public enum BASEvolutionarySearch {
    public struct Individual<T> {
        public let value: T
        public let fitness: Double
        public let generation: Int
        public let seed: UInt32
    }

    /// Run a generation-based mutation+selection loop。
    /// - Parameters:
    ///   - seed: starting input
    ///   - generations: how many generations to evolve (typical 3-10)
    ///   - childrenPerGen: children produced per generation (typical 8-32)
    ///   - survivors: top K individuals retained between generations
    ///   - mutate: function producing one child from one parent + RNG
    ///   - fitness: function scoring an individual — higher = better
    ///   - rng: inout PRNG (determinism preserved across runs)
    /// - Returns: best individual found across all generations
    public static func evolve<T>(
        seed: T,
        generations: Int = 5,
        childrenPerGen: Int = 8,
        survivors: Int = 2,
        mutate: (T, inout BASFuzzRng) -> T,
        fitness: (T) -> Double,
        rng: inout BASFuzzRng
    ) -> Individual<T> {
        var population: [Individual<T>] = [
            Individual(value: seed,
                       fitness: fitness(seed),
                       generation: 0,
                       seed: rng.state),
        ]
        var bestEver = population[0]
        for gen in 1...generations {
            var children: [Individual<T>] = []
            for parent in population {
                for _ in 0..<childrenPerGen {
                    let parentSeed = rng.state
                    let child = mutate(parent.value, &rng)
                    let f = fitness(child)
                    children.append(Individual(
                        value: child,
                        fitness: f,
                        generation: gen,
                        seed: parentSeed))
                }
            }
            // Sort descending by fitness,keep top K
            children.sort { $0.fitness > $1.fitness }
            population = Array(children.prefix(survivors))
            if let topChild = population.first,
               topChild.fitness > bestEver.fitness {
                bestEver = topChild
            }
        }
        return bestEver
    }
}
