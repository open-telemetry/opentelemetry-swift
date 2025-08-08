//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

#include "OtelAtomicInt32.h"

void otel_atomic_int32_init(otel_atomic_int32_t* a, int32_t value) {
    atomic_init(&a->v, value);
}

int32_t otel_atomic_int32_load(const otel_atomic_int32_t* a) {
    return atomic_load_explicit(&a->v, memory_order_relaxed);
}

void otel_atomic_int32_store(otel_atomic_int32_t* a, int32_t value) {
    atomic_store_explicit(&a->v, value, memory_order_relaxed);
}

int32_t otel_atomic_int32_exchange(otel_atomic_int32_t* a, int32_t value) {
    return atomic_exchange_explicit(&a->v, value, memory_order_relaxed);
}

bool otel_atomic_int32_compare_exchange(otel_atomic_int32_t* a, int32_t* expected, int32_t desired) {
    return atomic_compare_exchange_strong_explicit(
                                                   &a->v, expected, desired,
                                                   memory_order_relaxed,  // success
                                                   memory_order_relaxed   // failure
                                                   );
}

int32_t otel_atomic_int32_fetch_add(otel_atomic_int32_t* a, int32_t delta) {
    return atomic_fetch_add_explicit(&a->v, delta, memory_order_relaxed);
}

int32_t otel_atomic_int32_fetch_sub(otel_atomic_int32_t* a, int32_t delta) {
    return atomic_fetch_sub_explicit(&a->v, delta, memory_order_relaxed);
}
