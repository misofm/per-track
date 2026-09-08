# Security Audit — `per_track`

**Revision:** working tree @ 2026-08-23 (the `misonetwork` workspace is not a
git repository — `git rev-parse` fails; no commit hash exists). Dependency pin:
`musicos` (protocol) @ `ecb3da52c14912e257f00b30185c598e92ffc5e3`; the audited
`musicos::release` source is the on-disk `../protocol` working tree. Pin bumped
2026-08-23: `musicos` @ `c23fe7f…` (carrying the `miso_share` treasury-cap
hardening `d67ff8c`).
**Date:** 2026-08-23 · **Toolchain:** sui 1.77.2-51d177ad7d65

Audit of `per_track` (89 LOC, `sources/per_track.move`), the
`PerTrack<Data>` parallel-array container used by `release_cover_art`,
`release_genre`, and `release_dsp_link` to hold one payload per release track.
Verdict: **safe to publish — no findings.**

## What it does

`PerTrack<Data: store + drop>` (`per_track.move:36`) wraps a
`vector<Data>` meant to be index-aligned with a release's frozen tracklist:

- `new` (`per_track.move:42`) aborts unless `entries.length() ==
  release.tracks().length()` — alignment is established at construction.
- `filled` (`per_track.move:51`) builds a same-length vector of copies of one
  value.
- `borrow`/`borrow_mut` (`per_track.move:76,63`) are bounds-checked
  (`EIndexOutOfBounds`).
- `length` (`per_track.move:71`).

## Threat model

- **Misaligned parallel array (wrong track gets wrong metadata):** prevented by
  construction — both public constructors size/validate against
  `release.tracks().length()`, and a release's tracklist is frozen at creation
  (`musicos::release` embeds `tracks: vector<Track>` set once in `release::new`,
  immutable after publish; there is no track-add/remove API at all), so an
  aligned `PerTrack` can never drift out of alignment.
- **Out-of-bounds access:** both accessors assert `i < length` before indexing.
- **DoS via `filled`:** loop bound is the track count, itself capped at
  `MAX_TRACKS = 255` in `musicos::release` (`release.move:115,230`) — ≤ 255
  `push_back`s of small values.
- **Unauthenticated mutation:** `borrow_mut` returns `&mut Data` to whoever
  holds `&mut PerTrack<Data>` — deliberately. The container is not the trust
  boundary: every consuming extension stores its `PerTrack` in a dynamic field
  on the release and only hands out mutable access after the
  `ReleaseAdminCap` gate (verified per extension in their own audits). The
  only alignment bypass, `from_entries_for_testing` (`per_track.move:87`), is
  `#[test_only]` and absent from published bytecode.
- **Abilities:** `store, drop` only — a `PerTrack` is not an object, cannot be
  transferred/shared on its own, and can be dropped only by-value by code that
  owns it (its holding extension). `Data` must be `drop`, so no
  resource-holding payload can be silently destroyed *through* this type
  beyond what the holding extension chooses.

## Findings

None.

## Edge cases verified

- Zero-track release → `filled` yields an empty array (`per_track.move:52-59`;
  test `filled_on_zero_track_release_is_empty`). (Note: production releases
  always have ≥ 1 track — `release::new` asserts `ENoTracks`,
  `release.move:229` — but the container is sound either way.)
- `borrow`/`borrow_mut` at `i == length` abort (test
  `borrow_past_end_aborts`).
- `new` with `entries.length() != tracks().length()` aborts
  (`ELengthMismatch`).

## Verification

- **9/9 unit tests pass** (`sui move test`, sui 1.77.2), including the
  length-mismatch abort and per-track ordering test against a real `Release`.
