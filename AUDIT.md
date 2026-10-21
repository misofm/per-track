# Security Review — `release_track_data`

**Date:** 2026-10-20 · **Toolchain:** Sui 1.82.1 · **miso_music:** `c5a4a3f`

Review of `ReleaseTrackData<Data>`, the parallel-array container that per-track
release extensions use to hold one payload per track. Verdict: **safe to
publish — no findings.**

## What it does

`ReleaseTrackData<Data: store + drop>` wraps a `vector<Data>` index-aligned with
`release.recording_ids()`:

- `new` aborts with `ELengthMismatch` unless `entries.length()` equals the
  release's track count.
- `filled` builds one copy of `value` per track.
- `borrow` and `borrow_mut` assert `i < length` (`EIndexOutOfBounds`).
- `length` returns the number of tracks covered.

## Threat model

- **Misaligned data:** both constructors size or validate against
  `release.recording_ids()`, and the tracklist is fixed at release creation, so
  an instance stays aligned for the release's life.
- **Out-of-bounds access:** both accessors check the index before indexing.
- **Unbounded work:** `filled` loops once per track, bounded by
  `miso_music::release` `MAX_TRACKS = 1_000`.
- **Unauthenticated mutation:** `borrow_mut` serves whoever holds
  `&mut ReleaseTrackData`. The container is not the trust boundary; consuming
  extensions store it on the release and gate mutable access by
  `ReleaseAdminCap`. The alignment bypass `from_entries_for_testing` is
  `#[test_only]`.
- **Abilities:** `store + drop` only; it is not an object and `Data` must be
  `drop`, so no resource can be destroyed through it.

## Findings

None.

## Verification

14 unit tests pass with 100% coverage. They cover `new` with too few and too
many entries, `borrow` and `borrow_mut` at exactly `i == length` and beyond,
zero-track and `release::max_tracks()` releases for `new` and `filled`, and
positional alignment: data built from `recording_ids()` matches it at every
index.
