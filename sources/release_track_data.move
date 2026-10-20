// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// `ReleaseTrackData<Data>`: one `Data` value per track of a release, in
/// tracklist order.
///
/// Index `i` holds the data for the `i`-th recording in
/// `release.recording_ids()`. Construction checks the length against the
/// tracklist, which is frozen at release creation, so the data stays aligned
/// for the release's whole life. Used by per-track release metadata such as
/// cover art (`ReleaseTrackData<Option<CoverArt>>`).
module release_track_data::release_track_data;

use musicos::release::Release;

// === Errors ===

/// Track index is past the end of the data.
const EIndexOutOfBounds: u64 = 0;
/// `entries` length does not match the release's track count.
const ELengthMismatch: u64 = 1;

// === Structs ===

/// One `Data` per track, indexed by tracklist position. `Data` is `CoverArt`
/// when every track carries one, or `Option<CoverArt>` for overrides of an
/// album-level default.
public struct ReleaseTrackData<Data: store + drop>(vector<Data>) has store, drop;

// === Public Functions ===

/// Builds a `ReleaseTrackData` from one value per track, in tracklist order.
/// Aborts unless `entries.length()` equals the release's track count.
public fun new<Data: store + drop>(
    release: &Release,
    entries: vector<Data>,
): ReleaseTrackData<Data> {
    assert!(entries.length() == release.recording_ids().length(), ELengthMismatch);
    ReleaseTrackData(entries)
}

/// Builds a `ReleaseTrackData` sized to the release's track count, with every
/// track initialized to `value`. The natural starting point for override-style
/// metadata: fill with `option::none()`, then set individual tracks via
/// `borrow_mut`.
public fun filled<Data: store + drop + copy>(
    release: &Release,
    value: Data,
): ReleaseTrackData<Data> {
    let n = release.recording_ids().length();
    let mut entries = vector[];
    let mut i = 0;
    while (i < n) {
        entries.push_back(value);
        i = i + 1;
    };
    ReleaseTrackData(entries)
}

/// Borrows the payload for track `i` mutably. Aborts if `i` is out of range.
public fun borrow_mut<Data: store + drop>(self: &mut ReleaseTrackData<Data>, i: u64): &mut Data {
    assert!(i < self.0.length(), EIndexOutOfBounds);
    &mut self.0[i]
}

// === View Functions ===

/// The number of tracks this covers.
public fun length<Data: store + drop>(self: &ReleaseTrackData<Data>): u64 {
    self.0.length()
}

/// Borrows the payload for track `i`. Aborts if `i` is out of range.
public fun borrow<Data: store + drop>(self: &ReleaseTrackData<Data>, i: u64): &Data {
    assert!(i < self.0.length(), EIndexOutOfBounds);
    &self.0[i]
}

// === Test Functions ===

/// Builds a `ReleaseTrackData` directly from `entries`, bypassing the release
/// check, so the index/bounds logic can be unit-tested without a `Release`.
/// The release-bound invariant is exercised by the consuming extensions' tests.
#[test_only]
public fun from_entries_for_testing<Data: store + drop>(
    entries: vector<Data>,
): ReleaseTrackData<Data> {
    ReleaseTrackData(entries)
}
