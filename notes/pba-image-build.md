# PBA / rescue image build (notes for a future write-up)

Status: **TODO, write the full step-by-step build and flash procedure.**
These are the facts established on 2026-10-23 by inspecting this repo; they are
the starting point for that write-up.

## What is on the drive (as far as the repo shows)

- The last images built here are `images/UEFI64/UEFI64-1.49.13-dirty.img.gz` and
  `images/RESCUE64/RESCUE64-1.49.13-dirty.img`, built 2025-05-10 ~22:40 and
  committed as "Update PBA image" (43e2ecf) the next day. Not verified against
  the drive itself (that needs root and `sedutil-cli --query`).
- **The `1.49.13` in the file name is misleading.** `images/buildrescue` names the
  image from `git describe --dirty` of *this* repo, but the sedutil inside the
  image is built by Buildroot from `images/buildroot/package/sedutil/`, which
  pins **`SEDUTIL_VERSION = 1.20.0`**.
- The source Buildroot built (`images/scratch/buildroot/64bit/build/sedutil-1.20.0/`)
  is the official DTA tag `1.20.0` (d3de8e4, 2021-08-18). Of 103 source files only
  two differ, both compile fixes: `#include <cstdint>` in `Common/DtaOptions.h` and
  `#include <time.h>` in `Common/log.h`.
- The tarball it came from is `images/scratch/buildroot/dl/sedutil/sedutil-1.20.0.tar.gz`
  (2025-05-10 21:00). A second tarball, `images/scratch/buildroot/dl/sedutil-1.20.0.tar.gz`
  (21:27), is a `make dist` of the newer tree with the new salt; it was **not** what
  got built. The `sedutil-1.20.0.tar.gz` in the repo root (2026-04-16) is also a
  `make dist` of the newer tree, despite its name.

## Why the version matters: password hashing

If this 1.20.0 PBA is what unlocks the drive at boot, the credential stored on
the drive must match 1.20.0's derivation: PBKDF2-HMAC-SHA1 (75000 iterations,
32 bytes) **salted with the polished serial number**. The newer code on `ben` salts with the raw
`passwordSalt` bytes instead. Same password, different hash. See
`s3-sleep-password-hash-findings.md`.

Consequence for a rebuild: an image built from `ben` instead of 1.20.0 would
derive a different hash from the same password and may fail to unlock the
drive. Either keep building the PBA from 1.20.0, or re-set the password with
the new code before flashing a newer PBA.

## How the build is wired

- Host tools: `docker/` (Ubuntu 24.04 build container; the committed scripts call
  `podman`, but only `docker` is installed on this laptop. Stash
  "WIP on ben: 43e2ecf" switches them to `docker`.)
- `images/conf`: `SYSLINUX=syslinux-6.03`, Buildroot from gitlab, tag `2025.02.1`.
- `images/buildpbaroot`: clones `scratch/buildroot.git`, checks out the tag, copies
  `images/buildroot/{64bit,package/sedutil,patches}` in, runs `make O=64bit`
  twice (the first pass fails on sedutil's `Version.h`; the script regenerates it),
  then copies `linuxpba` and `sedutil-cli` into `64bit/sbin`.
- `images/buildrescue` / the UEFI image script: assemble the bootable image with
  syslinux from `scratch/syslinux-6.03`.
- `images/buildroot/syslinux.cfg`: commit 7d87645 ("AMD Ryzen laptop keyboard fix")
  removed `acpi=off noapic` from the `append` line. Going by the commit title,
  that is what fixed the keyboard in the PBA, but this has not been tested
  separately. It also left bare `acpi=off` / `nomodeset` lines under `kernel`;
  these are not syslinux keywords, so syslinux most likely ignores them (they
  are not passed to the kernel), but that is also unverified.
- `images/scratch/` (~12 GB) is the Buildroot work tree and can be regenerated.

## Still to work out for the write-up

- Exact flash procedure (`--loadPBAimage`, `--setMBREnable`, etc.) and the order of
  steps for a fresh drive vs. updating the PBA.
- Confirm which image is actually on the drive.
- Whether to keep the PBA on 1.20.0 or move to the newer code (and re-set the password).
