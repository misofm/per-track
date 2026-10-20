// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// `ReleaseTrackData<Data>` is a pure `store, drop` value (no `key`/`UID`): it is
/// never owned, shared, or transferred, so there is no ownership mechanic for
/// `test_scenario` to exercise. `new`/`filled` do read a `&Release`, but only
/// as a local, unshared reference used to size/validate the array in the same
/// transaction it is built in — plain `tx_context::dummy()` construction
/// models that faithfully; the release-bound *lifecycle* (publish, share,
/// take_shared) belongs to the consuming extensions' own e2e tests.
#[test_only]
module release_track_data::release_track_data_tests;

use musicos::release;
use std::unit_test::destroy;
use sui::event;
use release_track_data::release_track_data;

/// A fake object id — a `UID` created and immediately deleted, so the id is
/// real (derivable, unique) but nothing backs it. Good enough for track
/// payload fields that `ReleaseTrackData`'s alignment logic never inspects.
fun fake_id(ctx: &mut TxContext): ID {
    let uid = object::new(ctx);
    let id = uid.to_inner();
    uid.delete();
    id
}

/// A release with `n` tracks; only the tracklist length matters to `ReleaseTrackData`.
fun release_with_tracks(n: u64, ctx: &mut TxContext): release::Release {
    let release_id = fake_id(ctx);
    let mut tracks = vector[];
    n.do!(|_| tracks.push_back(release::consent_for_testing(fake_id(ctx), release_id)));
    let (rel, cap) = release::new_for_testing(tracks, ctx);
    destroy(cap);
    rel
}

#[test]
fun length_and_borrow() {
    let entries = release_track_data::from_entries_for_testing(vector[10u64, 20, 30]);
    assert!(entries.length() == 3);
    assert!(*entries.borrow(0) == 10);
    assert!(*entries.borrow(2) == 30);
}

#[test]
fun borrow_mut_replaces_entry() {
    let mut entries = release_track_data::from_entries_for_testing(vector[1u64, 2, 3]);
    *entries.borrow_mut(1) = 99;
    assert!(*entries.borrow(1) == 99);
}

#[test]
fun empty_has_zero_length() {
    let entries = release_track_data::from_entries_for_testing<u64>(vector[]);
    assert!(entries.length() == 0);
}

#[test, expected_failure(abort_code = release_track_data::EIndexOutOfBounds)]
fun borrow_past_end_aborts() {
    let entries = release_track_data::from_entries_for_testing(vector[1u64]);
    entries.borrow(5);
}

#[test, expected_failure(abort_code = release_track_data::EIndexOutOfBounds)]
fun borrow_mut_past_end_aborts() {
    let mut entries = release_track_data::from_entries_for_testing(vector[1u64]);
    entries.borrow_mut(5);
}

// === Release-bound construction ===

#[test]
fun new_builds_one_entry_per_track_in_order() {
    let mut ctx = tx_context::dummy();
    let rel = release_with_tracks(3, &mut ctx);

    let track_data = release_track_data::new(&rel, vector[10u64, 20, 30]);
    assert!(track_data.length() == 3);
    assert!(*track_data.borrow(0) == 10);
    assert!(*track_data.borrow(1) == 20);
    assert!(*track_data.borrow(2) == 30);

    destroy(track_data);
    destroy(rel);
}

#[test, expected_failure(abort_code = release_track_data::ELengthMismatch)]
fun new_aborts_when_entries_length_does_not_match_tracklist() {
    let mut ctx = tx_context::dummy();
    let rel = release_with_tracks(2, &mut ctx);

    let track_data = release_track_data::new(&rel, vector[10u64]); // 1 entry for a 2-track release
    destroy(track_data);
    destroy(rel);
}

#[test]
fun filled_sizes_to_tracklist_and_repeats_value() {
    let mut ctx = tx_context::dummy();
    let rel = release_with_tracks(4, &mut ctx);

    let track_data = release_track_data::filled(&rel, true);
    assert!(track_data.length() == 4);
    assert!(*track_data.borrow(0));
    assert!(*track_data.borrow(3));

    destroy(track_data);
    destroy(rel);
}

#[test]
fun filled_on_zero_track_release_is_empty() {
    let mut ctx = tx_context::dummy();
    let rel = release_with_tracks(0, &mut ctx);

    let track_data = release_track_data::filled(&rel, 7u64);
    assert!(track_data.length() == 0);

    destroy(track_data);
    destroy(rel);
}

#[test]
fun constructors_emit_no_events() {
    let mut ctx = tx_context::dummy();
    let rel = release_with_tracks(2, &mut ctx);
    let empty_rel = release_with_tracks(0, &mut ctx);
    let events_before = event::num_events();

    let data_new = release_track_data::new(&rel, vector[10u64, 20]);
    let data_filled = release_track_data::filled(&rel, 7u64);
    let empty_new = release_track_data::new<u64>(&empty_rel, vector[]);
    let empty_filled = release_track_data::filled(&empty_rel, 9u64);

    assert!(event::num_events() == events_before);
    destroy(data_new);
    destroy(data_filled);
    destroy(empty_new);
    destroy(empty_filled);
    destroy(rel);
    destroy(empty_rel);
}

#[test]
fun borrow_mut_without_write_emits_no_events_and_preserves_value() {
    let mut entries = release_track_data::from_entries_for_testing(vector[10u64, 20, 30]);
    let events_before = event::num_events();

    entries.borrow_mut(1);

    assert!(event::num_events() == events_before);
    assert!(*entries.borrow(1) == 20);
}

#[test]
fun views_emit_no_events() {
    let entries = release_track_data::from_entries_for_testing(vector[10u64, 20, 30]);
    let events_before = event::num_events();

    assert!(entries.length() == 3);
    assert!(*entries.borrow(0) == 10);
    assert!(*entries.borrow(2) == 30);
    assert!(event::num_events() == events_before);
}
