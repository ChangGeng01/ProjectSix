// Copyright © 2024 Apple Inc.

#include "mlx/event.h"
#include "mlx/backend/metal/device.h"
#include "mlx/scheduler.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>

namespace mlx::core {

namespace {
// ── BAS / ADR-038 §10.2 + task A (Metal-vs-MLX root cause) ──────────────────────────────────────
// The on-device decode wedge is MLX-process-local: the CPU parks in Event::wait() ->
// waitUntilSignaledValue(value(), -1) forever, while the GPU is provably healthy (a sibling Metal
// queue keeps completing during the wedge — ADR-038 §10.2). The `-1` fills the uint64 milliseconds
// timeout slot with UINT64_MAX, so the throw below is unreachable: an uncancellable infinite hang.
//
// This opt-in knob makes that wait FINITE so we can (a) localize the cause — log the event's target
// vs signaled value at the hang — and (b) convert the uncancellable hang into a CATCHABLE timeout
// (the throw becomes reachable -> propagates as an error -> the Swift evalLock.withLock releases ->
// a chance at in-process recovery instead of a permanent process-wide freeze).
//
// DEFAULT: env unset -> timeout = UINT64_MAX, i.e. EXACTLY the upstream `-1` behavior (byte- and
// behavior-identical; this is a synchronization primitive, no computed value crosses it). Set
// MLX_EVENT_WAIT_TIMEOUT_MS=<ms> (e.g. 30000) to opt into the bounded+diagnosed path.
inline uint64_t bas_event_wait_timeout_ms() {
  static const uint64_t cached = []() -> uint64_t {
    const char* e = std::getenv("MLX_EVENT_WAIT_TIMEOUT_MS");
    if (e != nullptr && *e != '\0') {
      long long n = std::atoll(e);
      if (n >= 0) {
        return static_cast<uint64_t>(n);
      }
    }
    return ~static_cast<uint64_t>(0); // UINT64_MAX == upstream `-1`
  }();
  return cached;
}
} // namespace

Event::Event(Stream stream) : stream_(stream) {
  auto dtor = [](void* ptr) {
    auto p = metal::new_scoped_memory_pool();
    static_cast<MTL::SharedEvent*>(ptr)->release();
  };
  auto p = metal::new_scoped_memory_pool();
  event_ = std::shared_ptr<void>(
      metal::device(Device::gpu).mtl_device()->newSharedEvent(), dtor);
  if (event_ == nullptr) {
    throw std::runtime_error(
        "[Event::Event] Failed to create Metal shared event.");
  }
}

void Event::wait() {
  auto* ev = static_cast<MTL::SharedEvent*>(event_.get());
  const uint64_t timeout = bas_event_wait_timeout_ms();
  if (!ev->waitUntilSignaledValue(value(), timeout)) {
    // Reachable only when MLX_EVENT_WAIT_TIMEOUT_MS is set to a finite value. Log the event state at
    // the hang (BAS/ADR-038 §10.2 A): signaled < target ⇒ the GPU never reached the encoded signal
    // (MLX submission/scheduling/dependency issue); signaled >= target ⇒ a wait/API race.
    std::fprintf(stderr,
                 "[BAS][Event::wait] TIMEOUT after %llums target=%llu signaled=%llu\n",
                 static_cast<unsigned long long>(timeout),
                 static_cast<unsigned long long>(value()),
                 static_cast<unsigned long long>(ev->signaledValue()));
    std::fflush(stderr);
    throw std::runtime_error("[Event::wait] Timed out");
  }
}

void Event::wait(Stream stream) {
  if (stream.device == Device::cpu) {
    scheduler::enqueue(stream, [*this]() mutable { wait(); });
  } else {
    auto& d = metal::device(stream.device);
    d.end_encoding(stream.index);
    auto command_buffer = d.get_command_buffer(stream.index);
    command_buffer->encodeWait(static_cast<MTL::Event*>(event_.get()), value());
    command_buffer->addCompletedHandler([*this](MTL::CommandBuffer*) {});
  }
}

void Event::signal(Stream stream) {
  if (stream.device == Device::cpu) {
    scheduler::enqueue(stream, [*this]() mutable {
      static_cast<MTL::SharedEvent*>(event_.get())->setSignaledValue(value());
    });
  } else {
    auto& d = metal::device(stream.device);
    d.end_encoding(stream.index);
    auto command_buffer = d.get_command_buffer(stream.index);
    command_buffer->encodeSignalEvent(
        static_cast<MTL::Event*>(event_.get()), value());
    command_buffer->addCompletedHandler([*this](MTL::CommandBuffer*) {});
  }
}

bool Event::is_signaled() const {
  return static_cast<MTL::SharedEvent*>(event_.get())->signaledValue() >=
      value();
}

} // namespace mlx::core
