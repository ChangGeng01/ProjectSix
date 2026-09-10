// SPDX:internal
//
// kv_cache.rs — chapter 七百三 第二刀 / M2172
//
// Rust port of BASKVCacheRegistry (Sources/BASRuntimeCore/)。
// TTL-based key-value cache with manual eviction + monotonic
// clock injection for deterministic testing。

use std::collections::BTreeMap;
use std::sync::Mutex;

/// Invalidation policy mirroring the Swift `BASKVCache
/// InvalidationPolicy` enum。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum InvalidationPolicy {
    /// No automatic eviction — entries stay until explicitly
    /// removed。
    Never,
    /// Time-to-live based eviction;entries older than `ttl_ms`
    /// are evicted on access。
    Ttl,
    /// Manual write-invalidation — entries are evicted only
    /// when the caller explicitly invalidates a key range。
    Manual,
}

/// One cache entry。
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Entry {
    pub key: String,
    pub value: Vec<u8>,
    pub put_at_ms: i64,
}

/// Injectable monotonic clock so tests can advance time without
/// real sleeping。
pub trait Clock: Send + Sync {
    fn now_ms(&self) -> i64;
}

/// Default real-wall-clock。 Production uses this。
pub struct RealClock;
impl Clock for RealClock {
    fn now_ms(&self) -> i64 {
        use std::time::{SystemTime, UNIX_EPOCH};
        SystemTime::now().duration_since(UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0)
    }
}

pub struct KVCacheRegistry {
    inner: Mutex<KVState>,
}

struct KVState {
    policy: InvalidationPolicy,
    ttl_ms: i64,
    entries: BTreeMap<String, Entry>,
    clock: Box<dyn Clock>,
}

impl KVCacheRegistry {
    pub fn new(
        policy: InvalidationPolicy, ttl_ms: i64,
    ) -> Self {
        Self::with_clock(policy, ttl_ms, Box::new(RealClock))
    }

    pub fn with_clock(
        policy: InvalidationPolicy,
        ttl_ms: i64,
        clock: Box<dyn Clock>,
    ) -> Self {
        Self {
            inner: Mutex::new(KVState {
                policy, ttl_ms, clock,
                entries: BTreeMap::new(),
            })
        }
    }

    pub fn put(&self, key: &str, value: Vec<u8>) {
        let mut s = self.inner.lock().unwrap();
        let now = s.clock.now_ms();
        s.entries.insert(
            key.to_string(),
            Entry { key: key.to_string(), value,
                put_at_ms: now });
    }

    pub fn get(&self, key: &str) -> Option<Vec<u8>> {
        let mut s = self.inner.lock().unwrap();
        let now = s.clock.now_ms();
        // For TTL policy, evict on access if expired。
        if let InvalidationPolicy::Ttl = s.policy {
            if let Some(e) = s.entries.get(key) {
                if now - e.put_at_ms >= s.ttl_ms {
                    s.entries.remove(key);
                    return None;
                }
            }
        }
        s.entries.get(key).map(|e| e.value.clone())
    }

    pub fn invalidate(&self, key: &str) {
        let mut s = self.inner.lock().unwrap();
        s.entries.remove(key);
    }

    /// Manual sweep — drop all entries older than ttl_ms。
    /// Returns the number of entries evicted。
    pub fn sweep_expired(&self) -> usize {
        let mut s = self.inner.lock().unwrap();
        let now = s.clock.now_ms();
        let ttl = s.ttl_ms;
        let stale: Vec<String> = s.entries.iter()
            .filter(|(_, e)| now - e.put_at_ms >= ttl)
            .map(|(k, _)| k.clone())
            .collect();
        let n = stale.len();
        for k in stale {
            s.entries.remove(&k);
        }
        n
    }

    pub fn count(&self) -> usize {
        self.inner.lock().unwrap().entries.len()
    }

    pub fn policy(&self) -> InvalidationPolicy {
        self.inner.lock().unwrap().policy
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicI64, Ordering};
    use std::sync::Arc;

    /// Controllable clock for deterministic tests。
    struct ControlClock(Arc<AtomicI64>);
    impl Clock for ControlClock {
        fn now_ms(&self) -> i64 {
            self.0.load(Ordering::SeqCst)
        }
    }
    fn clock() -> (Box<dyn Clock>, Arc<AtomicI64>) {
        let t = Arc::new(AtomicI64::new(0));
        (Box::new(ControlClock(t.clone())), t)
    }

    #[test]
    fn put_get_basic() {
        let cache = KVCacheRegistry::new(
            InvalidationPolicy::Never, 0);
        cache.put("k", b"v".to_vec());
        assert_eq!(cache.get("k"), Some(b"v".to_vec()));
    }

    #[test]
    fn get_unknown_returns_none() {
        let cache = KVCacheRegistry::new(
            InvalidationPolicy::Never, 0);
        assert_eq!(cache.get("missing"), None);
    }

    #[test]
    fn ttl_eviction_on_access() {
        let (clock, t) = clock();
        let cache = KVCacheRegistry::with_clock(
            InvalidationPolicy::Ttl, 1000, clock);
        t.store(0, Ordering::SeqCst);
        cache.put("k", b"v".to_vec());
        // Within TTL, still present。
        t.store(500, Ordering::SeqCst);
        assert!(cache.get("k").is_some());
        // After TTL, evicted on access。
        t.store(1500, Ordering::SeqCst);
        assert!(cache.get("k").is_none());
        assert_eq!(cache.count(), 0);
    }

    #[test]
    fn never_policy_does_not_evict() {
        let (clock, t) = clock();
        let cache = KVCacheRegistry::with_clock(
            InvalidationPolicy::Never, 100, clock);
        t.store(0, Ordering::SeqCst);
        cache.put("k", b"v".to_vec());
        t.store(1_000_000, Ordering::SeqCst);
        assert!(cache.get("k").is_some());
    }

    #[test]
    fn manual_invalidate() {
        let cache = KVCacheRegistry::new(
            InvalidationPolicy::Manual, 0);
        cache.put("k", b"v".to_vec());
        cache.invalidate("k");
        assert!(cache.get("k").is_none());
    }

    #[test]
    fn sweep_expired_count() {
        let (clock, t) = clock();
        let cache = KVCacheRegistry::with_clock(
            InvalidationPolicy::Ttl, 1000, clock);
        t.store(0, Ordering::SeqCst);
        cache.put("a", b"1".to_vec());
        cache.put("b", b"2".to_vec());
        cache.put("c", b"3".to_vec());
        t.store(1500, Ordering::SeqCst);
        cache.put("d", b"4".to_vec());
        let evicted = cache.sweep_expired();
        assert_eq!(evicted, 3);
        assert_eq!(cache.count(), 1);
        assert!(cache.get("d").is_some());
    }

    #[test]
    fn policy_accessor() {
        let cache = KVCacheRegistry::new(
            InvalidationPolicy::Manual, 0);
        assert_eq!(cache.policy(), InvalidationPolicy::Manual);
    }

    #[test]
    fn put_replaces_existing_with_fresh_timestamp() {
        let (clock, t) = clock();
        let cache = KVCacheRegistry::with_clock(
            InvalidationPolicy::Ttl, 1000, clock);
        t.store(0, Ordering::SeqCst);
        cache.put("k", b"v1".to_vec());
        t.store(500, Ordering::SeqCst);
        cache.put("k", b"v2".to_vec());
        // Original would have expired at 1000, but the put at
        // 500 reset the clock so it survives until 1500。
        t.store(1400, Ordering::SeqCst);
        assert_eq!(cache.get("k"), Some(b"v2".to_vec()));
        t.store(1500, Ordering::SeqCst);
        assert!(cache.get("k").is_none());
    }
}
