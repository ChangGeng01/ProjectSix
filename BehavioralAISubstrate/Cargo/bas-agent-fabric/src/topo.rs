// SPDX:internal
//
// topo.rs — O(V+E) Kahn topological sort with cycle detection。
// Parity with Swift's `BASAgentMergeEngine.topologicalSort`
// (chapter 九百五十六.5 USER-PASS gap #3 + chapter 九百五十六.6
// O(V+E) perf rewrite)。
//
// API takes pre-resolved &str references for both nodes and
// dependency-edge sources。 Caller is responsible for stripping
// the "delta:" prefix from dependency refs before passing in
// (mirrors what Swift does at the boundary)。 External deps
// (depID not in node set) are silently dropped per Swift contract。
//
// Stable in-degree-zero seed order:lex-ascending by node id,
// matching Swift's `sorted { $0.deltaID < $1.deltaID }`。 This
// is for determinism only — actual conflict resolution happens
// in `winner::pick_winner`,not topo sort。

use std::collections::BTreeMap;
use std::collections::BTreeSet;
use std::vec::Vec;

/// Result of one topological sort run。 `sorted` contains node
/// ids in dependency-respecting order;`cycle_participants` lists
/// nodes that could not be emitted because they participate in a
/// cycle (or depend on one)。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopoOutcome<'a> {
    pub sorted: Vec<&'a str>,
    pub cycle_participants: BTreeSet<&'a str>,
}

/// O(V+E) Kahn topological sort。 `nodes` is the full node set;
/// `dependencies` maps each node id → its dependency ids (nodes
/// that must come before it)。 Returns sorted output + cycle
/// participants。
///
/// Implementation matches Swift `BASAgentMergeEngine.topologicalSort`
/// (chapter 九百五十六.6 perf rewrite) step-for-step:
///   1. ONE pass to index canonical node-id → index
///   2. ONE pass to build forward adjacency [dep → [dependents]]
///   3. ONE pass to compute in-degree
///   4. Seed queue with in-degree-0 nodes in lex order
///   5. Standard Kahn loop with head-pointer queue (O(1) dequeue)
///   6. Unreached nodes = cycle participants
pub fn topological_sort<'a, K>(
    nodes: &'a [K],
    dependencies: &BTreeMap<K, Vec<K>>,
) -> TopoOutcome<'a>
where
    K: AsRef<str> + Ord,
{
    let n = nodes.len();
    // Index by node id
    let mut index_by_id: BTreeMap<&str, usize> = BTreeMap::new();
    for (i, node) in nodes.iter().enumerate() {
        index_by_id.insert(node.as_ref(), i);
    }
    // Resolve dependencies → in-set indices only
    let mut resolved_deps: Vec<Vec<usize>> = (0..n).map(|_| Vec::new()).collect();
    for (i, node) in nodes.iter().enumerate() {
        if let Some(deps) = dependencies.get(node) {
            for dep in deps {
                if let Some(&dep_idx) = index_by_id.get(dep.as_ref()) {
                    resolved_deps[i].push(dep_idx);
                }
            }
        }
    }
    // Forward adjacency + in-degree
    let mut dependents: Vec<Vec<usize>> =
        (0..n).map(|_| Vec::new()).collect();
    let mut in_degree: Vec<usize> = (0..n).map(|_| 0).collect();
    for (i, deps) in resolved_deps.iter().enumerate() {
        for &dep_idx in deps {
            dependents[dep_idx].push(i);
            in_degree[i] += 1;
        }
    }
    // Seed queue with in-degree-0 nodes in lex order
    let mut seed: Vec<usize> = (0..n)
        .filter(|&i| in_degree[i] == 0)
        .collect();
    seed.sort_by(|&a, &b| {
        nodes[a].as_ref().cmp(nodes[b].as_ref())
    });
    let mut queue: Vec<usize> = seed;
    let mut head: usize = 0;
    let mut sorted: Vec<&str> = Vec::with_capacity(n);
    while head < queue.len() {
        let current = queue[head];
        head += 1;
        sorted.push(nodes[current].as_ref());
        for &dep_idx in &dependents[current] {
            in_degree[dep_idx] -= 1;
            if in_degree[dep_idx] == 0 {
                queue.push(dep_idx);
            }
        }
    }
    // Cycle participants = nodes not in sorted output
    let emitted: BTreeSet<&str> = sorted.iter().copied().collect();
    let mut cycle_participants: BTreeSet<&str> = BTreeSet::new();
    for node in nodes {
        let id = node.as_ref();
        if !emitted.contains(id) {
            cycle_participants.insert(id);
        }
    }
    TopoOutcome { sorted, cycle_participants }
}
