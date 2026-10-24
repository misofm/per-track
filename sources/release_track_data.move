// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

module release_track_data::release_track_data;

// === Imports ===

use miso_music::release::Release;

// === Errors ===

const EIndexOutOfBounds: u64 = 0;
const ELengthMismatch: u64 = 1;

// === Structs ===

public struct ReleaseTrackData<Data: store + drop>(vector<Data>) has store, drop;

// === Public Functions ===

public fun new<Data: store + drop>(
    release: &Release,
    entries: vector<Data>,
): ReleaseTrackData<Data> {
    assert!(entries.length() == release.tracks().length(), ELengthMismatch);
    ReleaseTrackData(entries)
}

public fun filled<Data: store + drop + copy>(
    release: &Release,
    value: Data,
): ReleaseTrackData<Data> {
    ReleaseTrackData(vector::tabulate!(release.tracks().length(), |_| value))
}

public fun borrow_mut<Data: store + drop>(self: &mut ReleaseTrackData<Data>, i: u64): &mut Data {
    assert!(i < self.0.length(), EIndexOutOfBounds);
    &mut self.0[i]
}

// === View Functions ===

public fun length<Data: store + drop>(self: &ReleaseTrackData<Data>): u64 {
    self.0.length()
}

public fun borrow<Data: store + drop>(self: &ReleaseTrackData<Data>, i: u64): &Data {
    assert!(i < self.0.length(), EIndexOutOfBounds);
    &self.0[i]
}

// === Test Functions ===

#[test_only]
public fun from_entries_for_testing<Data: store + drop>(
    entries: vector<Data>,
): ReleaseTrackData<Data> {
    ReleaseTrackData(entries)
}
