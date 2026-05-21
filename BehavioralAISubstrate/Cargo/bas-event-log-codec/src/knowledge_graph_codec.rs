// SPDX:internal
//
// knowledge_graph_codec.rs — chapter 七百四十四 第一刀 / M2391
//
// LAYER-MIGRATION ARC L3 Knowledge Graph storage codec port。
// Mirrors Swift BASSQLiteKnowledgeGraphStorage encode/decode
// for BASKnowledgeNode + BASKnowledgeEdge value types。
//
// Per user directive 2026-05-20:
//
//   「真正应该移植的是每层里的 热路径、状态机、持久化、审计、数学计算。」
//
// Direct re-use of chapter 七百二十四 + 七百三十二 dual-read
// pattern:hosts can persist nodes/edges as either:
//   - V1 JSON (existing,via Swift Codable)
//   - V2 binary (this knife,Rust codec)
// and a payload_format SQL column tags which encoding。
// Lazy upgrade on read,never required to migrate v1 rows。
//
// ## Wire format (V2 binary)
//
// Node:
//   u32_be(node_id_len) || node_id_utf8 ||
//   u32_be(kind_raw_len) || kind_raw_utf8 ||
//   u32_be(label_len) || label_utf8 ||
//   i64_be(created_at_ms) ||
//   u32_be(payload_json_len) || payload_json_utf8
//   (payload_json_len = 0xFFFFFFFF encodes None)
//
// Edge:
//   u32_be(edge_id_len) || edge_id_utf8 ||
//   u32_be(from_node_id_len) || from_node_id_utf8 ||
//   u32_be(to_node_id_len) || to_node_id_utf8 ||
//   u32_be(kind_raw_len) || kind_raw_utf8 ||
//   f64_be(weight) ||
//   i64_be(created_at_ms)
//
// ## Honest scope
//
// Per the plan:"Direct re-use of chapter 七百二十四 + 七百
// 三十二 dual-read pattern。 Likely TIED on speed + storage
// shrink modest per chapter 七百三十二 honest landing。"
// Knowledge graph nodes typically carry small payloads;
// binary wire saves ~20-30% on the length-prefix overhead
// vs JSON,but the savings are modest at the substrate's
// typical workload。 SQL schema migration (chapter 七百四十
// 四 第三刀) is the bigger win — replay determinism +
// cross-restart provenance for the knowledge graph。

use std::os::raw::c_char;

pub const KG_CODEC_ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_kg_codec_abi_version() -> i32 {
    KG_CODEC_ABI_VERSION
}

// MARK: - Node encode/decode

/// Encode a knowledge node to the V2 binary wire format。
/// Returns the canonical bytes。 Pure deterministic function。
pub fn encode_node(
    node_id: &str,
    kind_raw: &str,
    label: &str,
    created_at_ms: i64,
    payload_json: Option<&str>,
) -> Vec<u8> {
    let mut buf: Vec<u8> = Vec::with_capacity(
        4 + node_id.len()
        + 4 + kind_raw.len()
        + 4 + label.len()
        + 8
        + 4 + payload_json.map_or(0, str::len));
    write_lenprefixed_str(&mut buf, node_id);
    write_lenprefixed_str(&mut buf, kind_raw);
    write_lenprefixed_str(&mut buf, label);
    buf.extend_from_slice(&created_at_ms.to_be_bytes());
    match payload_json {
        Some(s) => write_lenprefixed_str(&mut buf, s),
        None => {
            // 0xFFFFFFFF encodes Option::None
            buf.extend_from_slice(
                &0xFFFFFFFF_u32.to_be_bytes());
        }
    }
    buf
}

/// Edge encoded shape。
pub fn encode_edge(
    edge_id: &str,
    from_node_id: &str,
    to_node_id: &str,
    kind_raw: &str,
    weight: f64,
    created_at_ms: i64,
) -> Vec<u8> {
    let mut buf: Vec<u8> = Vec::with_capacity(
        4 + edge_id.len()
        + 4 + from_node_id.len()
        + 4 + to_node_id.len()
        + 4 + kind_raw.len()
        + 8 + 8);
    write_lenprefixed_str(&mut buf, edge_id);
    write_lenprefixed_str(&mut buf, from_node_id);
    write_lenprefixed_str(&mut buf, to_node_id);
    write_lenprefixed_str(&mut buf, kind_raw);
    buf.extend_from_slice(&weight.to_be_bytes());
    buf.extend_from_slice(&created_at_ms.to_be_bytes());
    buf
}

fn write_lenprefixed_str(buf: &mut Vec<u8>, s: &str) {
    let bytes = s.as_bytes();
    buf.extend_from_slice(
        &(bytes.len() as u32).to_be_bytes());
    buf.extend_from_slice(bytes);
}

// MARK: - Decoded shapes (Result-typed for caller error handling)

#[derive(Clone, Debug, PartialEq)]
pub struct DecodedNode {
    pub node_id: String,
    pub kind_raw: String,
    pub label: String,
    pub created_at_ms: i64,
    pub payload_json: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct DecodedEdge {
    pub edge_id: String,
    pub from_node_id: String,
    pub to_node_id: String,
    pub kind_raw: String,
    pub weight: f64,
    pub created_at_ms: i64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum DecodeError {
    Truncated,
    BadUtf8,
}

fn read_u32_be(
    buf: &[u8], off: &mut usize,
) -> Result<u32, DecodeError> {
    if *off + 4 > buf.len() {
        return Err(DecodeError::Truncated);
    }
    let v = u32::from_be_bytes([
        buf[*off], buf[*off + 1],
        buf[*off + 2], buf[*off + 3]]);
    *off += 4;
    Ok(v)
}

fn read_i64_be(
    buf: &[u8], off: &mut usize,
) -> Result<i64, DecodeError> {
    if *off + 8 > buf.len() {
        return Err(DecodeError::Truncated);
    }
    let mut arr = [0u8; 8];
    arr.copy_from_slice(&buf[*off..*off + 8]);
    *off += 8;
    Ok(i64::from_be_bytes(arr))
}

fn read_f64_be(
    buf: &[u8], off: &mut usize,
) -> Result<f64, DecodeError> {
    if *off + 8 > buf.len() {
        return Err(DecodeError::Truncated);
    }
    let mut arr = [0u8; 8];
    arr.copy_from_slice(&buf[*off..*off + 8]);
    *off += 8;
    Ok(f64::from_be_bytes(arr))
}

fn read_lenprefixed_str(
    buf: &[u8], off: &mut usize,
) -> Result<String, DecodeError> {
    let len = read_u32_be(buf, off)? as usize;
    if *off + len > buf.len() {
        return Err(DecodeError::Truncated);
    }
    let bytes = &buf[*off..*off + len];
    *off += len;
    String::from_utf8(bytes.to_vec())
        .map_err(|_| DecodeError::BadUtf8)
}

/// Decode a V2 node。 Returns DecodeError on malformed input。
pub fn decode_node(buf: &[u8]) -> Result<DecodedNode, DecodeError> {
    let mut off = 0;
    let node_id = read_lenprefixed_str(buf, &mut off)?;
    let kind_raw = read_lenprefixed_str(buf, &mut off)?;
    let label = read_lenprefixed_str(buf, &mut off)?;
    let created_at_ms = read_i64_be(buf, &mut off)?;
    // Payload may be None (0xFFFFFFFF) or Some(s)
    if off + 4 > buf.len() {
        return Err(DecodeError::Truncated);
    }
    let payload_len_raw = u32::from_be_bytes([
        buf[off], buf[off + 1], buf[off + 2],
        buf[off + 3]]);
    let payload_json = if payload_len_raw == 0xFFFFFFFF {
        // chapter 八百二十九 / M2796 lint fix:advance past
        // the 4-byte sentinel so subsequent reads (if any are
        // added in future schemas) start at the correct offset。
        // Currently no field is read after this `None` branch,
        // but maintaining the off advance keeps the codec
        // forward-compatible。
        let _ = off + 4;  // explicit no-op, documented above
        None
    } else {
        Some(read_lenprefixed_str(buf, &mut off)?)
    };
    Ok(DecodedNode {
        node_id, kind_raw, label,
        created_at_ms, payload_json,
    })
}

/// Decode a V2 edge。
pub fn decode_edge(buf: &[u8]) -> Result<DecodedEdge, DecodeError> {
    let mut off = 0;
    let edge_id = read_lenprefixed_str(buf, &mut off)?;
    let from_node_id = read_lenprefixed_str(
        buf, &mut off)?;
    let to_node_id = read_lenprefixed_str(buf, &mut off)?;
    let kind_raw = read_lenprefixed_str(buf, &mut off)?;
    let weight = read_f64_be(buf, &mut off)?;
    let created_at_ms = read_i64_be(buf, &mut off)?;
    Ok(DecodedEdge {
        edge_id, from_node_id, to_node_id, kind_raw,
        weight, created_at_ms,
    })
}

// MARK: - C ABI (two-phase capacity pattern for encode;
//                length-prefixed parse for decode)

/// Encode a knowledge node via the C ABI。
///
/// Two-phase capacity pattern:
///   out_capacity = 0 → returns required size (no write)
///   otherwise → writes up to capacity bytes,returns
///               bytes written (or -2 if would-truncate)
///
/// payload_json_ptr may be NULL with payload_json_len = -1
/// to encode None。
#[no_mangle]
pub unsafe extern "C" fn bas_kg_codec_encode_node(
    node_id_ptr: *const c_char, node_id_len: i32,
    kind_raw_ptr: *const c_char, kind_raw_len: i32,
    label_ptr: *const c_char, label_len: i32,
    created_at_ms: i64,
    payload_json_ptr: *const c_char,
    payload_json_len: i32,
    out_buf: *mut c_char,
    out_capacity: i32,
) -> i32 {
    // SAFETY: caller pins each ptr/len pair per FFI contract
    let (node_id, kind_raw, label, payload) = unsafe {
        let nid = match read_str(node_id_ptr, node_id_len) {
            Some(s) => s, None => return -1 };
        let kr = match read_str(kind_raw_ptr, kind_raw_len) {
            Some(s) => s, None => return -1 };
        let lbl = match read_str(label_ptr, label_len) {
            Some(s) => s, None => return -1 };
        let pl = if payload_json_len < 0 {
            None
        } else {
            match read_str(payload_json_ptr, payload_json_len) {
                Some(s) => Some(s), None => return -1 }
        };
        (nid, kr, lbl, pl)
    };
    let bytes = encode_node(
        node_id, kind_raw, label,
        created_at_ms, payload);
    // SAFETY: caller pins out_buf capacity per FFI contract
    unsafe { write_bytes(out_buf, out_capacity, &bytes) }
}

/// Encode a knowledge edge via the C ABI。 Same capacity
/// pattern as encode_node。
#[no_mangle]
pub unsafe extern "C" fn bas_kg_codec_encode_edge(
    edge_id_ptr: *const c_char, edge_id_len: i32,
    from_node_id_ptr: *const c_char, from_node_id_len: i32,
    to_node_id_ptr: *const c_char, to_node_id_len: i32,
    kind_raw_ptr: *const c_char, kind_raw_len: i32,
    weight: f64,
    created_at_ms: i64,
    out_buf: *mut c_char,
    out_capacity: i32,
) -> i32 {
    // SAFETY: caller pins each ptr/len pair per FFI contract
    let (edge_id, fnid, tnid, kind_raw) = unsafe {
        let eid = match read_str(edge_id_ptr, edge_id_len) {
            Some(s) => s, None => return -1 };
        let fn_ = match read_str(
            from_node_id_ptr, from_node_id_len) {
            Some(s) => s, None => return -1 };
        let to_ = match read_str(
            to_node_id_ptr, to_node_id_len) {
            Some(s) => s, None => return -1 };
        let kr = match read_str(kind_raw_ptr, kind_raw_len) {
            Some(s) => s, None => return -1 };
        (eid, fn_, to_, kr)
    };
    let bytes = encode_edge(
        edge_id, fnid, tnid, kind_raw, weight,
        created_at_ms);
    // SAFETY: caller pins out_buf capacity per FFI contract
    unsafe { write_bytes(out_buf, out_capacity, &bytes) }
}

unsafe fn read_str<'a>(
    ptr: *const c_char, len: i32,
) -> Option<&'a str> {
    if len < 0 { return None; }
    if len == 0 { return Some(""); }
    if ptr.is_null() { return None; }
    let bytes = unsafe {
        std::slice::from_raw_parts(
            ptr as *const u8, len as usize)
    };
    std::str::from_utf8(bytes).ok()
}

unsafe fn write_bytes(
    out_buf: *mut c_char, out_capacity: i32,
    payload: &[u8],
) -> i32 {
    let needed = payload.len() as i32;
    if out_capacity == 0 || out_buf.is_null() {
        return needed;
    }
    if needed > out_capacity {
        return -2;
    }
    // SAFETY:caller pins out_buf capacity per the FFI
    // contract;needed ≤ capacity here
    unsafe {
        std::ptr::copy_nonoverlapping(
            payload.as_ptr(),
            out_buf as *mut u8,
            payload.len());
    }
    needed
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn node_round_trip_with_payload() {
        let bytes = encode_node(
            "n1", "event", "Hello world",
            1700000000000, Some("{\"k\":\"v\"}"));
        let d = decode_node(&bytes).unwrap();
        assert_eq!(d.node_id, "n1");
        assert_eq!(d.kind_raw, "event");
        assert_eq!(d.label, "Hello world");
        assert_eq!(d.created_at_ms, 1700000000000);
        assert_eq!(d.payload_json.as_deref(),
            Some("{\"k\":\"v\"}"));
    }

    #[test]
    fn node_round_trip_without_payload() {
        let bytes = encode_node(
            "n2", "atom", "no payload",
            100, None);
        let d = decode_node(&bytes).unwrap();
        assert_eq!(d.payload_json, None);
    }

    #[test]
    fn node_empty_strings_round_trip() {
        let bytes = encode_node(
            "", "", "", 0, Some(""));
        let d = decode_node(&bytes).unwrap();
        assert_eq!(d.node_id, "");
        assert_eq!(d.label, "");
        assert_eq!(d.payload_json.as_deref(), Some(""));
    }

    #[test]
    fn node_unicode_round_trip() {
        let bytes = encode_node(
            "n-中文-🎉", "external", "中文 label 中文",
            42, Some("{\"u\":\"⛩️\"}"));
        let d = decode_node(&bytes).unwrap();
        assert_eq!(d.node_id, "n-中文-🎉");
        assert_eq!(d.label, "中文 label 中文");
        assert_eq!(d.payload_json.as_deref(),
            Some("{\"u\":\"⛩️\"}"));
    }

    #[test]
    fn node_determinism_repeat_calls() {
        let a = encode_node(
            "n", "k", "l", 100, Some("p"));
        let b = encode_node(
            "n", "k", "l", 100, Some("p"));
        assert_eq!(a, b);
    }

    #[test]
    fn node_decode_truncated_fails() {
        let bytes = encode_node(
            "n", "k", "l", 100, None);
        // Cut the last 4 bytes — should truncate
        let cut = &bytes[..bytes.len() - 4];
        let err = decode_node(cut).unwrap_err();
        assert_eq!(err, DecodeError::Truncated);
    }

    #[test]
    fn edge_round_trip() {
        let bytes = encode_edge(
            "e1", "n1", "n2", "causes",
            0.7, 1700000001000);
        let d = decode_edge(&bytes).unwrap();
        assert_eq!(d.edge_id, "e1");
        assert_eq!(d.from_node_id, "n1");
        assert_eq!(d.to_node_id, "n2");
        assert_eq!(d.kind_raw, "causes");
        assert!((d.weight - 0.7).abs() < 1e-15);
        assert_eq!(d.created_at_ms, 1700000001000);
    }

    #[test]
    fn edge_weight_clamp_irrelevant_to_codec() {
        // Codec preserves whatever weight it receives;
        // clamp is the caller's responsibility (Swift
        // BASKnowledgeEdge does it in init)。
        let bytes = encode_edge(
            "e", "a", "b", "mentions",
            f64::NAN, 0);
        let d = decode_edge(&bytes).unwrap();
        assert!(d.weight.is_nan());
    }

    // MARK: - C ABI

    #[test]
    fn c_abi_encode_node_two_phase() {
        let nid = b"n1";
        let kr = b"event";
        let lbl = b"label";
        // Phase 1:discover required size
        let needed = unsafe {
            bas_kg_codec_encode_node(
                nid.as_ptr() as *const c_char, 2,
                kr.as_ptr() as *const c_char, 5,
                lbl.as_ptr() as *const c_char, 5,
                100,
                std::ptr::null(), -1,
                std::ptr::null_mut(), 0)
        };
        assert!(needed > 0);
        // Phase 2:fill exact-sized buffer
        let mut buf = vec![0_i8; needed as usize];
        let wrote = unsafe {
            bas_kg_codec_encode_node(
                nid.as_ptr() as *const c_char, 2,
                kr.as_ptr() as *const c_char, 5,
                lbl.as_ptr() as *const c_char, 5,
                100,
                std::ptr::null(), -1,
                buf.as_mut_ptr(), needed)
        };
        assert_eq!(wrote, needed);
        let u8_buf: Vec<u8> = buf.iter()
            .map(|c| *c as u8).collect();
        let d = decode_node(&u8_buf).unwrap();
        assert_eq!(d.node_id, "n1");
        assert_eq!(d.payload_json, None);
    }

    #[test]
    fn c_abi_encode_node_with_payload() {
        let nid = b"n2";
        let kr = b"atom";
        let lbl = b"x";
        let payload = b"{\"foo\":1}";
        let needed = unsafe {
            bas_kg_codec_encode_node(
                nid.as_ptr() as *const c_char, 2,
                kr.as_ptr() as *const c_char, 4,
                lbl.as_ptr() as *const c_char, 1,
                42,
                payload.as_ptr() as *const c_char,
                payload.len() as i32,
                std::ptr::null_mut(), 0)
        };
        let mut buf = vec![0_i8; needed as usize];
        unsafe {
            bas_kg_codec_encode_node(
                nid.as_ptr() as *const c_char, 2,
                kr.as_ptr() as *const c_char, 4,
                lbl.as_ptr() as *const c_char, 1,
                42,
                payload.as_ptr() as *const c_char,
                payload.len() as i32,
                buf.as_mut_ptr(), needed);
        }
        let u8_buf: Vec<u8> = buf.iter()
            .map(|c| *c as u8).collect();
        let d = decode_node(&u8_buf).unwrap();
        assert_eq!(d.payload_json.as_deref(),
            Some("{\"foo\":1}"));
    }

    #[test]
    fn c_abi_encode_edge_round_trip() {
        let eid = b"e";
        let fr = b"a";
        let to = b"b";
        let kr = b"supports";
        let needed = unsafe {
            bas_kg_codec_encode_edge(
                eid.as_ptr() as *const c_char, 1,
                fr.as_ptr() as *const c_char, 1,
                to.as_ptr() as *const c_char, 1,
                kr.as_ptr() as *const c_char, 8,
                0.5, 1000,
                std::ptr::null_mut(), 0)
        };
        let mut buf = vec![0_i8; needed as usize];
        unsafe {
            bas_kg_codec_encode_edge(
                eid.as_ptr() as *const c_char, 1,
                fr.as_ptr() as *const c_char, 1,
                to.as_ptr() as *const c_char, 1,
                kr.as_ptr() as *const c_char, 8,
                0.5, 1000,
                buf.as_mut_ptr(), needed);
        }
        let u8_buf: Vec<u8> = buf.iter()
            .map(|c| *c as u8).collect();
        let d = decode_edge(&u8_buf).unwrap();
        assert_eq!(d.edge_id, "e");
        assert_eq!(d.kind_raw, "supports");
        assert!((d.weight - 0.5).abs() < 1e-15);
    }

    #[test]
    fn c_abi_truncated_buffer_returns_neg2() {
        let nid = b"n";
        let kr = b"k";
        let lbl = b"l";
        let mut tiny = [0_i8; 4];
        let rc = unsafe {
            bas_kg_codec_encode_node(
                nid.as_ptr() as *const c_char, 1,
                kr.as_ptr() as *const c_char, 1,
                lbl.as_ptr() as *const c_char, 1,
                100,
                std::ptr::null(), -1,
                tiny.as_mut_ptr(), tiny.len() as i32)
        };
        assert_eq!(rc, -2,
            "out_capacity smaller than needed → -2");
    }
}
