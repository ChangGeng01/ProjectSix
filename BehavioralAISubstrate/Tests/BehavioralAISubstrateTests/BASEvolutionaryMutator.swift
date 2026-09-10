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

// MARK: - Crossover operators
// chapter 九百五十二 / M3465 — user directive 「进化 算法 加强」
//
// Crossover combines two parents into a child by mixing their
// content。 Compared to mutation,crossover preserves「good blocks」
// from both parents — important for evolving structured inputs
// where multiple parents may have discovered different bug-finding
// fragments。
//
// All crossovers are deterministic given an inout BASFuzzRng so the
// same seed produces identical children — required for CI
// reproducibility per chapter 946 fuzz protocol。

/// Byte-array crossover operators。
public enum BASByteCrossover {
    /// Single-point crossover: pick split point,take prefix from A,
    /// suffix from B (output length = midpoint(A.count, B.count))。
    public static func singlePoint(
        _ a: [UInt8],
        _ b: [UInt8],
        rng: inout BASFuzzRng
    ) -> [UInt8] {
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        let minLen = min(a.count, b.count)
        let split = rng.nextInt(upTo: minLen)
        return Array(a.prefix(split)) + Array(b.suffix(from: split))
    }

    /// Uniform crossover: per-byte coin flip choosing parent。
    /// Output length = min(A.count, B.count)。 More aggressive mixing
    /// than single-point — useful when bug-triggering inputs are
    /// distributed across many byte positions。
    public static func uniform(
        _ a: [UInt8],
        _ b: [UInt8],
        rng: inout BASFuzzRng
    ) -> [UInt8] {
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        let len = min(a.count, b.count)
        var out: [UInt8] = []
        out.reserveCapacity(len)
        for i in 0..<len {
            out.append(rng.nextBool() ? a[i] : b[i])
        }
        return out
    }

    /// Two-point crossover: pick two split points,middle segment
    /// comes from B,outer from A。 Preserves block structure better
    /// than uniform for inputs where contiguous regions matter
    /// (e.g. JSON,serialized structs)。
    public static func twoPoint(
        _ a: [UInt8],
        _ b: [UInt8],
        rng: inout BASFuzzRng
    ) -> [UInt8] {
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        let minLen = min(a.count, b.count)
        if minLen < 3 { return singlePoint(a, b, rng: &rng) }
        let p1 = rng.nextInt(upTo: minLen)
        let p2 = rng.nextInt(in: p1...(minLen - 1))
        var out: [UInt8] = []
        out.reserveCapacity(a.count)
        out.append(contentsOf: a.prefix(p1))
        out.append(contentsOf: b[p1..<p2])
        out.append(contentsOf: a.suffix(from: p2))
        return out
    }

    /// Pick a random crossover (1 of 3)。
    public static func cross(
        _ a: [UInt8],
        _ b: [UInt8],
        rng: inout BASFuzzRng
    ) -> [UInt8] {
        switch rng.nextInt(upTo: 3) {
        case 0: return singlePoint(a, b, rng: &rng)
        case 1: return uniform(a, b, rng: &rng)
        default: return twoPoint(a, b, rng: &rng)
        }
    }
}

/// Float-vector crossover operators。
public enum BASFloatVectorCrossover {
    /// Uniform crossover — per-element coin flip。
    public static func uniform(
        _ a: [Float],
        _ b: [Float],
        rng: inout BASFuzzRng
    ) -> [Float] {
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        let len = min(a.count, b.count)
        var out: [Float] = []
        out.reserveCapacity(len)
        for i in 0..<len {
            out.append(rng.nextBool() ? a[i] : b[i])
        }
        return out
    }

    /// Arithmetic crossover — weighted average per element。
    /// Useful for numerical inputs where averaging makes sense
    /// (smooth function inputs,probability distributions)。
    public static func arithmetic(
        _ a: [Float],
        _ b: [Float],
        rng: inout BASFuzzRng
    ) -> [Float] {
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        let len = min(a.count, b.count)
        let alpha = rng.nextFloat(in: 0...1)
        var out: [Float] = []
        out.reserveCapacity(len)
        for i in 0..<len {
            out.append(a[i] * alpha + b[i] * (1 - alpha))
        }
        return out
    }

    /// Pick a random crossover (1 of 2)。
    public static func cross(
        _ a: [Float],
        _ b: [Float],
        rng: inout BASFuzzRng
    ) -> [Float] {
        rng.nextBool()
            ? uniform(a, b, rng: &rng)
            : arithmetic(a, b, rng: &rng)
    }
}

/// String crossover operators。
public enum BASStringCrossover {
    /// Single-point crossover on Unicode scalars (NOT UTF-8 bytes,
    /// to avoid splitting a multi-byte char mid-encoding)。
    public static func singlePoint(
        _ a: String,
        _ b: String,
        rng: inout BASFuzzRng
    ) -> String {
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        let aScalars = Array(a.unicodeScalars)
        let bScalars = Array(b.unicodeScalars)
        let splitA = rng.nextInt(upTo: aScalars.count + 1)
        let splitB = rng.nextInt(upTo: bScalars.count + 1)
        var out = String()
        for i in 0..<splitA { out.unicodeScalars.append(aScalars[i]) }
        for i in splitB..<bScalars.count {
            out.unicodeScalars.append(bScalars[i])
        }
        return out
    }

    /// Interleave by Unicode scalar — pull alternating scalars。
    public static func interleave(
        _ a: String,
        _ b: String,
        rng: inout BASFuzzRng
    ) -> String {
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        let aScalars = Array(a.unicodeScalars)
        let bScalars = Array(b.unicodeScalars)
        let len = min(aScalars.count, bScalars.count)
        var out = String()
        for i in 0..<len {
            out.unicodeScalars.append(
                rng.nextBool() ? aScalars[i] : bScalars[i])
        }
        return out
    }

    /// Pick a random crossover (1 of 2)。
    public static func cross(
        _ a: String,
        _ b: String,
        rng: inout BASFuzzRng
    ) -> String {
        rng.nextBool()
            ? singlePoint(a, b, rng: &rng)
            : interleave(a, b, rng: &rng)
    }
}

// MARK: - Multi-objective fitness

/// Multi-objective fitness composition。 Per ch 952 user directive
/// 「极致 找到 所有 缺陷 bug 不足」 — single-axis fitness can converge
/// on local optima。 Real-world fuzz wants to balance:
///   - coverage (did we hit new code paths?)
///   - latency (do slow inputs reveal perf bugs?)
///   - shape diversity (don't get stuck on one length / one type)
///   - failure rate (did inputs CRASH or just succeed?)
public struct BASMultiObjectiveFitness {
    public let coverageScore: Double      // higher = more code paths hit
    public let latencyMs: Double          // higher = slower (perf bug bait)
    public let diversityScore: Double     // higher = different from prior
    public let failureFlag: Double        // 1.0 if input crashed,0 otherwise

    public init(
        coverageScore: Double,
        latencyMs: Double,
        diversityScore: Double,
        failureFlag: Double
    ) {
        self.coverageScore = coverageScore
        self.latencyMs = latencyMs
        self.diversityScore = diversityScore
        self.failureFlag = failureFlag
    }

    /// Weighted-sum scalarization。 Caller picks weights。 Default
    /// emphasizes coverage + failures (the two clearest bug signals)。
    public func weightedSum(
        wCoverage: Double = 1.0,
        wLatency: Double = 0.1,
        wDiversity: Double = 0.5,
        wFailure: Double = 10.0
    ) -> Double {
        return wCoverage * coverageScore +
               wLatency * latencyMs +
               wDiversity * diversityScore +
               wFailure * failureFlag
    }
}

/// Pareto dominance check。 A dominates B if A is ≥ B on every
/// dimension AND > B on at least one。 Pareto-best individuals
/// are non-dominated。
public enum BASParetoDominance {
    public static func dominates(
        _ a: BASMultiObjectiveFitness,
        _ b: BASMultiObjectiveFitness
    ) -> Bool {
        let aDims = [a.coverageScore, a.latencyMs,
                     a.diversityScore, a.failureFlag]
        let bDims = [b.coverageScore, b.latencyMs,
                     b.diversityScore, b.failureFlag]
        var atLeastOneStrict = false
        for i in 0..<aDims.count {
            if aDims[i] < bDims[i] { return false }
            if aDims[i] > bDims[i] { atLeastOneStrict = true }
        }
        return atLeastOneStrict
    }

    /// Find non-dominated subset (Pareto front) of a population。
    public static func paretoFront<T>(
        _ population: [(T, BASMultiObjectiveFitness)]
    ) -> [(T, BASMultiObjectiveFitness)] {
        return population.enumerated().compactMap { (idx, item) in
            let dominated = population.enumerated().contains { (j, other) in
                j != idx && dominates(other.1, item.1)
            }
            return dominated ? nil : item
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

    /// Evolutionary loop WITH crossover + tournament selection。
    /// chapter 九百五十二 — extends `evolve` with:
    ///   - Multiple seeds to start (more genetic diversity)
    ///   - Crossover between top parents (combine good blocks)
    ///   - Tournament selection (random pairs compete,winner reproduces)
    ///   - Elitism (best-ever always survives — prevents regression)
    public static func evolveWithCrossover<T>(
        seeds: [T],
        generations: Int = 5,
        childrenPerGen: Int = 8,
        survivors: Int = 2,
        crossover: (T, T, inout BASFuzzRng) -> T,
        mutate: (T, inout BASFuzzRng) -> T,
        fitness: (T) -> Double,
        rng: inout BASFuzzRng
    ) -> Individual<T> {
        precondition(!seeds.isEmpty, "seeds must be non-empty")
        var population: [Individual<T>] = seeds.map { seed in
            Individual(value: seed,
                       fitness: fitness(seed),
                       generation: 0,
                       seed: rng.state)
        }
        // Sort initial population so bestEver is correct
        population.sort { $0.fitness > $1.fitness }
        var bestEver = population[0]
        for gen in 1...generations {
            var children: [Individual<T>] = []
            for _ in 0..<childrenPerGen {
                // Tournament selection: pick 2 random parents,
                // mate them or just mutate the winner。
                let p1 = population.randomTournament(rng: &rng)
                let p2 = population.randomTournament(rng: &rng)
                let parentSeed = rng.state
                let child: T
                if rng.nextBool(p: 0.6) {
                    // 60% crossover-then-mutate
                    let crossed = crossover(p1.value, p2.value, &rng)
                    child = mutate(crossed, &rng)
                } else {
                    // 40% pure mutation
                    child = mutate(p1.value, &rng)
                }
                children.append(Individual(
                    value: child,
                    fitness: fitness(child),
                    generation: gen,
                    seed: parentSeed))
            }
            children.sort { $0.fitness > $1.fitness }
            // Elitism: bestEver always survives
            var nextPop = Array(children.prefix(survivors))
            if !nextPop.contains(where: { $0.fitness >= bestEver.fitness }) {
                nextPop.append(bestEver)
            }
            population = nextPop
            if let topChild = children.first,
               topChild.fitness > bestEver.fitness {
                bestEver = topChild
            }
        }
        return bestEver
    }
}

// MARK: - Helpers for tournament selection

extension Array {
    /// Tournament selection — pick 2 random elements,return the
    /// one with higher fitness (assumes Element is Individual<T>)。
    /// Deterministic via inout RNG。
    func randomTournament<T>(
        rng: inout BASFuzzRng
    ) -> BASEvolutionarySearch.Individual<T>
        where Element == BASEvolutionarySearch.Individual<T>
    {
        precondition(!isEmpty, "tournament needs ≥ 1 individual")
        if count == 1 { return self[0] }
        let a = self[rng.nextInt(upTo: count)]
        let b = self[rng.nextInt(upTo: count)]
        return a.fitness >= b.fitness ? a : b
    }
}
