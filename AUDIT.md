# Security Audit — `release_track_data`

Audited at `269a9211f35889a724e1d5a0d43c22b5e5ec7130` (2026-10-21). Scope: package `release_track_data`, module `release_track_data::release_track_data` (`sources/release_track_data.move`), and the parts of `miso_music::release` @ `1538d77` that it relies on.

## What it does

`ReleaseTrackData<Data>` is a `store + drop` wrapper around a `vector<Data>`, sized to a release's tracklist. `release_cover_art` stores it. See [README](./README.md).

## Trust model

- No objects, capabilities, events or dynamic fields.
- **Anyone** holding a `&Release` may build an instance (`new`, `filled`; `release_track_data.move:21-34`).
- **Whoever holds `&mut ReleaseTrackData`** may replace any entry (`borrow_mut`, `release_track_data.move:36-39`). The container is not a trust boundary: the consuming extension stores it under the release's UID and gates mutable access with `ReleaseAdminCap`.
- **Nobody** can change the length after construction: the vector field is private and no function pushes or pops.

## Findings

**RTD-1 · Low · Open — an instance is not bound to the release it was sized for.** `new` and `filled` check against the `&Release` passed in (`release_track_data.move:25`, `33`), but the struct does not record that release's id (`release_track_data.move:17`). Because it has `store`, a container built from release A can be stored on release B (probe `built_for_a_used_with_b`: 2 entries attached alongside a 5-track release). The README's "an extension can't attach misaligned data" holds only if each consumer builds the container from the same release it stores it on. `release_cover_art` does (`release_cover_art.move` `borrow_mut_or_init`), but nothing in the type enforces it, and any consumer API that accepted a caller-supplied `ReleaseTrackData` would be exposed. Suggested fix: store the `release_id` in the struct and expose it, or have consumers assert `length() == release.recording_ids().length()`. Alternatively, narrow the README claim.

**RTD-2 · Info · Accepted — the zero-track path is test-only.** `filled_on_zero_track_release_is_empty` builds a release through `release::new_for_testing`, which skips the `ENoTracks` check. Real releases have 1 to 1,000 tracks (`release.move:97-98`).

## Checked, no finding

- `new` aborts `ELengthMismatch` on both too few and too many entries. `borrow` and `borrow_mut` abort `EIndexOutOfBounds` at `i == length` and beyond (`release_track_data.move:25`, `37`, `48`; unit tests).
- The tracklist cannot change: `Release.recording_ids` has no mutator (`release.move:30-34`, `179-181`), so a correctly built instance stays aligned.
- Mutating entries leaves the length unchanged (probe `length_fixed_after_mut`).
- Abilities: the wrapper is `store + drop`, and `Data` must be `drop`, so no value with obligations can be lost by dropping the container. `filled` additionally needs `copy`.
- `from_entries_for_testing` (the alignment bypass) is `#[test_only]` (`release_track_data.move:54-59`).
- Limits: `filled` runs one iteration per track, at most 1,000 (`release.move:27`). Storage is 1,000 × `size_of(Data)`. For `Option<CoverArt>` (about 70 bytes per entry) that stays well under Sui's 256 KB object limit. A consumer with `Data` larger than about 250 bytes could exceed the limit on a 1,000-track release.

## Operational requirements

- Consumers must build each container from the same `Release` whose UID they store it under, or assert the length when reading (RTD-1).

## Verification

- `sui move test --coverage`: 14/14 pass. `sui move coverage summary`: 100.00% (`release_track_data`).
- `sui move build -e mainnet --warnings-are-errors` and `-e testnet`: both succeed with no warnings (sui 1.82.1).
- 3 throwaway probe tests (cross-release use, drop, fixed length after mutation) all passed. They were not committed.
