//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

#ifndef __OTELATOMICINT32__
#define __OTELATOMICINT32__

#include <stdatomic.h>
#include <stdint.h>
#include <stdbool.h>

typedef struct { _Atomic int32_t v; } otel_atomic_int32_t;

void otel_atomic_int32_init(otel_atomic_int32_t* a, int32_t value);
int32_t otel_atomic_int32_load(const otel_atomic_int32_t* a);
void otel_atomic_int32_store(otel_atomic_int32_t* a, int32_t value);
int32_t otel_atomic_int32_exchange(otel_atomic_int32_t* a, int32_t value);
bool    otel_atomic_int32_compare_exchange(otel_atomic_int32_t* a, int32_t* expected, int32_t desired);
int32_t otel_atomic_int32_fetch_add(otel_atomic_int32_t* a, int32_t delta);
int32_t otel_atomic_int32_fetch_sub(otel_atomic_int32_t* a, int32_t delta);

#endif
