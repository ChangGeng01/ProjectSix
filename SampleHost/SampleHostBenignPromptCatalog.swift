// MARK: - SampleHostBenignPromptCatalog
//
// chapter 二百五 / M771 — benign prompts for substrate-engage path.
//
// User vision (chapter 188-190): bench data should train the model
// stronger over time. But chapter 196 + 200-prep + 204 ALL produced
// 100% substrate-skip — substrate's L7 (mirror) + L11 (risk-gate)
// correctly refuse LLM dispatch on the chapter-173+ adversarial
// catalog (prompts designed to stress-test substrate's risk
// detection). For training-data accumulation we need the OPPOSITE:
// genuinely low-risk prompts that substrate's L11 routes to
// `.answer` permit → AFM/Gemma actually fires.
//
// Doctrine pin (red line 7 + 不变量 #2): we DO NOT bypass
// substrate's risk evaluation. We just feed it prompts where the
// risk evaluation correctly returns LOW → substrate engages
// LLM → training data accumulates.
//
// Prompt design principles:
//   - Factual queries (no opinion / advice / decision)
//   - General-knowledge topics (no medical / financial / personal)
//   - Neutral tone (no emotional words)
//   - Bounded scope (single question per prompt)
//   - Stake = low (chapter 174+ stake taxonomy)
//
// 80 prompts × 5 mutationSeeds × stride rotation = lots of variation
// without re-using identical (signature, prompt) pairs in 100-iter
// anomaly-watcher windows.

import Foundation

enum SampleHostBenignPromptCatalog {
    /// 80 benign prompts spanning factual / translation / math /
    /// creative / programming / cooking / general-info domains.
    /// All chosen so substrate's L7 + L11 evaluation routes to
    /// `.answer` permit (i.e. LLM fires on most iters).
    static let benignPrompts: [String] = [
        // Factual general-knowledge (10)
        "What's the boiling point of water at sea level in Celsius?",
        "How many minutes are there in a single day?",
        "What's the capital city of Australia?",
        "Which planet in our solar system is closest to the Sun?",
        "How many continents are there on Earth?",
        "What's the chemical symbol for gold?",
        "Which year did the Wright brothers fly the first powered aircraft?",
        "What's the speed of light in vacuum, in kilometres per second?",
        "How many sides does a hexagon have?",
        "What's the largest mammal currently living on Earth?",

        // Translation (10)
        "Translate 'good morning' into Spanish.",
        "Translate 'thank you' into Japanese.",
        "Translate 'hello, friend' into French.",
        "Translate 'please pass the salt' into German.",
        "Translate 'where is the library?' into Italian.",
        "How do you say 'happy birthday' in Mandarin?",
        "Translate 'see you tomorrow' into Portuguese.",
        "What does 'gracias' mean in English?",
        "Translate 'a glass of water, please' into Russian.",
        "How do you say 'goodbye' in Korean?",

        // Math / arithmetic (10)
        "What is twelve times eight?",
        "Calculate two hundred forty divided by six.",
        "What's the square root of one hundred forty-four?",
        "Add the numbers fifteen, twenty-three, and forty-two.",
        "What's seven cubed?",
        "Convert two and a half hours into minutes.",
        "If a rectangle has length 6 and width 4, what's its area?",
        "What's the perimeter of a square with side length 7?",
        "Calculate fifteen percent of two hundred.",
        "What's the next prime number after eleven?",

        // Cooking (10)
        "How long should I boil a soft-boiled egg for?",
        "What's a basic recipe for plain pancakes for one person?",
        "How do I make a simple vinaigrette dressing?",
        "What temperature should I bake a 1kg chicken at and for how long?",
        "List three ingredients for a basic margherita pizza.",
        "How do I cook plain white rice on the stove?",
        "What's a simple way to peel garlic quickly?",
        "How long does dry pasta typically take to cook?",
        "What's a basic way to scramble eggs for two people?",
        "How do I store fresh basil so it lasts longer?",

        // Creative writing — bounded, low stake (10)
        "Write a four-line haiku about autumn leaves.",
        "Write a one-sentence description of a peaceful morning.",
        "Suggest three creative names for a small bookstore.",
        "Write a short two-line nursery rhyme about a cat.",
        "Compose a one-sentence weather report for a sunny day.",
        "Write a six-word story about a found coin.",
        "Suggest a creative title for a cookbook about soups.",
        "Write a two-line greeting card message for a new neighbour.",
        "Suggest three name ideas for a tortoise.",
        "Write one positive affirmation about morning routines.",

        // Programming — factual / definitional (10)
        "What does HTTP stand for?",
        "What's the difference between a list and a tuple in Python?",
        "Briefly: what is recursion in programming?",
        "What does the SQL keyword SELECT do?",
        "What's the purpose of indentation in Python?",
        "Briefly explain what a variable is in programming.",
        "What does JSON stand for?",
        "What's the difference between == and === in JavaScript?",
        "Briefly: what is a for-loop?",
        "What does the file extension .md typically indicate?",

        // Geography / general (10)
        "Which ocean is the largest by area?",
        "Name three rivers that flow through Europe.",
        "What's the longest mountain range in the world?",
        "Name three official languages of Switzerland.",
        "Which is the smallest country in the world by area?",
        "Name three countries that border France.",
        "What's the capital of Brazil?",
        "Through which countries does the Nile flow?",
        "Which sea is between Italy and Greece?",
        "Name three cities in Japan.",

        // Light hobbies / how-to (10)
        "How do I tie a basic shoelace knot in steps?",
        "What's a simple way to organise a small bookshelf?",
        "How can I make my houseplants last longer in winter?",
        "Suggest three indoor exercises that need no equipment.",
        "How do I clean a stainless steel kettle?",
        "What's a simple stretch I can do at my desk?",
        "How do I keep a notebook organised for daily use?",
        "Suggest three games to play with a regular deck of cards.",
        "How can I make my coffee taste smoother at home?",
        "Suggest three tips for writing a short to-do list.",
    ]

    /// Doctrine: all benign prompts use the same low-risk signature.
    /// Substrate sees consistently safe inputs and routes most to
    /// `.answer` permit. mutationSeed varies per iter so per-iter
    /// state varies (anomaly watcher / mutator etc) but signature
    /// stays low-risk.
    static let benignSignature = SampleHostPromptSignature(
        tone: "curious",
        domain: "creative",
        stake: "low",
        timeframe: "minutes",
        confidant: "decision-system",
        askShape: "single-action")

    /// Pick a prompt by iter (deterministic). Cycles through the
    /// 80-prompt list. mutationSeed (0..4) attached for downstream
    /// state variation. seed = iter for reproducibility.
    static func generate(forIter iter: Int)
        -> SampleHostGeneratedPrompt
    {
        let prompt = benignPrompts[iter % benignPrompts.count]
        return SampleHostGeneratedPrompt(
            signature: benignSignature,
            prompt: prompt,
            seed: iter)
    }
}
