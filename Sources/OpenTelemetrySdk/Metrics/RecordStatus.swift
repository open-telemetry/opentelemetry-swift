/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

enum RecordStatus {
    /// This applies to bound instruments that was created in response to user explicitly calling Bind.
    /// They must never be removed.
    case bound
    
    /// This applies to bound instruments that was created by MeterSDK intended to be short lived one.
    /// They currently have pending updates to be sent to MetricProcessor/Batcher/Exporter.
    /// Collect will move them to NoPendingUpdate after exporting updates.
    case updatePending
    
    /// This status is applied to UpdatePending instruments after Collect() is done.
    /// This will be moved to  CandidateForRemoval during the next Collect() cycle.
    /// If an update occurs, the instrument promotes them to UpdatePending.
    case noPendingUpdate
    
    /// This also applies to bound instruments that was created by MeterSDK intended to be short lived one.
    /// They have no pending update and has not been used since atleast one collect() cycle.
    /// Collect will set this status to all noPendingUpdate bound instruments after finishing a collect pass.
    /// Instrument records with this status are removed after collect().
    case candidateForRemoval
}
