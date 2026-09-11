// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// `PerTrack<Data>` is a pure `store, drop` value (no `key`/`UID`): it is
/// never owned, shared, or transferred, so there is no ownership mechanic for
/// `test_scenario` to exercise. `new`/`filled` do read a `&Release`, but only
/// as a local, unshared reference used to size/validate the array in the same
/// transaction it is built in — plain `tx_context::dummy()` construction
/// models that faithfully; the release-bound *lifecycle* (publish, share,
/// take_shared) belongs to the consuming extensions' own e2e tests.
#[test_only]
module per_track::per_track_tests;

use musicos::release;
use musicos::track;
use std::unit_test::destroy;
use sui::event;

// Alias the module so the bare address `per_track` resolves in
// `#[expected_failure(location = per_track::per_track)]` (avoids the
// addr==module name collision).
use per_track::per_track as pt;

/// A fake object id — a `UID` created and immediately deleted, so the id is
/// real (derivable, unique) but nothing backs it. Good enough for track
/// payload fields that `PerTrack`'s alignment logic never inspects.
fun fake_id(ctx: &mut TxContext): ID {
    let uid = object::new(ctx);
    let id = uid.to_inner();
    uid.delete();
    id
}

/// A release with `n` tracks, built without needing real composition/
/// recording objects — only `PerTrack`'s alignment-to-tracklist-length logic
/// is under test here, so the track payload's other fields are arbitrary.
fun release_with_tracks(n: u64, ctx: &mut TxContext): release::Release {
    let comp_id = fake_id(ctx);
    let rec_id = fake_id(ctx);
    let release_id = fake_id(ctx);
    let mut tracks = vector[];
    n.do!(|_| tracks.push_back(track::new_for_testing(comp_id, rec_id, release_id, 10000)));
    let (rel, cap) = release::new_for_testing(b"Album".to_string(), tracks, ctx);
    destroy(cap);
    rel
}

#[test]
fun length_and_borrow() {
    let entries = pt::from_entries_for_testing(vector[10u64, 20, 30]);
    assert!(entries.length() == 3);
    assert!(*entries.borrow(0) == 10);
    assert!(*entries.borrow(2) == 30);
}

#[test]
fun borrow_mut_replaces_entry() {
    let mut entries = pt::from_entries_for_testing(vector[1u64, 2, 3]);
    *entries.borrow_mut(1) = 99;
    assert!(*entries.borrow(1) == 99);
}

#[test]
fun empty_has_zero_length() {
    let entries = pt::from_entries_for_testing<u64>(vector[]);
    assert!(entries.length() == 0);
}

#[test, expected_failure(abort_code = 0, location = per_track::per_track)] // EIndexOutOfBounds
fun borrow_past_end_aborts() {
    let entries = pt::from_entries_for_testing(vector[1u64]);
    entries.borrow(5);
}

#[test, expected_failure(abort_code = 0, location = per_track::per_track)] // EIndexOutOfBounds
fun borrow_mut_past_end_aborts() {
    let mut entries = pt::from_entries_for_testing(vector[1u64]);
    entries.borrow_mut(5);
}

// === Release-bound construction ===

#[test]
fun new_builds_one_entry_per_track_in_order() {
    let mut ctx = tx_context::dummy();
    let rel = release_with_tracks(3, &mut ctx);

    let per = pt::new(&rel, vector[10u64, 20, 30]);
    assert!(per.length() == 3);
    assert!(*per.borrow(0) == 10);
    assert!(*per.borrow(1) == 20);
    assert!(*per.borrow(2) == 30);

    destroy(per);
    destroy(rel);
}

#[test, expected_failure(abort_code = 1, location = per_track::per_track)] // ELengthMismatch
fun new_aborts_when_entries_length_does_not_match_tracklist() {
    let mut ctx = tx_context::dummy();
    let rel = release_with_tracks(2, &mut ctx);

    let per = pt::new(&rel, vector[10u64]); // 1 entry for a 2-track release
    destroy(per);
    destroy(rel);
}

#[test]
fun filled_sizes_to_tracklist_and_repeats_value() {
    let mut ctx = tx_context::dummy();
    let rel = release_with_tracks(4, &mut ctx);

    let per = pt::filled(&rel, true);
    assert!(per.length() == 4);
    assert!(*per.borrow(0));
    assert!(*per.borrow(3));

    destroy(per);
    destroy(rel);
}

#[test]
fun filled_on_zero_track_release_is_empty() {
    let mut ctx = tx_context::dummy();
    let rel = release_with_tracks(0, &mut ctx);

    let per = pt::filled(&rel, 7u64);
    assert!(per.length() == 0);

    destroy(per);
    destroy(rel);
}

#[test]
fun constructors_emit_no_events() {
    let mut ctx = tx_context::dummy();
    let rel = release_with_tracks(2, &mut ctx);
    let empty_rel = release_with_tracks(0, &mut ctx);
    let events_before = event::num_events();

    let per_new = pt::new(&rel, vector[10u64, 20]);
    let per_filled = pt::filled(&rel, 7u64);
    let empty_new = pt::new<u64>(&empty_rel, vector[]);
    let empty_filled = pt::filled(&empty_rel, 9u64);

    assert!(event::num_events() == events_before);
    destroy(per_new);
    destroy(per_filled);
    destroy(empty_new);
    destroy(empty_filled);
    destroy(rel);
    destroy(empty_rel);
}

#[test]
fun borrow_mut_without_write_emits_no_events_and_preserves_value() {
    let mut entries = pt::from_entries_for_testing(vector[10u64, 20, 30]);
    let events_before = event::num_events();

    entries.borrow_mut(1);

    assert!(event::num_events() == events_before);
    assert!(*entries.borrow(1) == 20);
}

#[test]
fun views_emit_no_events() {
    let entries = pt::from_entries_for_testing(vector[10u64, 20, 30]);
    let events_before = event::num_events();

    assert!(entries.length() == 3);
    assert!(*entries.borrow(0) == 10);
    assert!(*entries.borrow(2) == 30);
    assert!(event::num_events() == events_before);
}
