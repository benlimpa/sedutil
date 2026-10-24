# S3 Sleep Password Hash Compatibility Findings

Date: 2026-04-19

## Question

Does `--prepareForS3Sleep` in the current worktree derive the same password hash as a sedutil PBA built from `1.20.0`, or were there hashing changes that require a different password?

## Conclusion

The PBKDF2 algorithm itself did not materially change between `1.20.0` and current `HEAD`, but the hash inputs did.

Two differences matter:

1. The salt source changed between `1.20.0` and current `HEAD`.
2. In the current worktree diff, hex translation now happens before hashing, which can change the hashed input bytes when `-t` or `-x` is used.

Because of the salt change alone, the same human-readable password can produce a different derived hash between a `1.20.0` PBA and current `HEAD`.

## What Stayed The Same

The underlying password derivation is still:

- `PBKDF2-HMAC-SHA1`
- `75000` iterations by default
- `32` output bytes

Evidence:

- `1.20.0` uses `cf_pbkdf2_hmac(..., &cf_sha1)` in `Common/DtaHashPwd.cpp`.
- Current `HEAD` uses `cf_pbkdf2_hmac(..., &cf_sha1)` in `Common/DtaHashPassword.cpp`.

Relevant current file:

- [Common/DtaHashPassword.cpp](/home/blimpan/projects/sedutil/Common/DtaHashPassword.cpp:41)

## Important Change 1: Salt Source

### `1.20.0`

In `1.20.0`, `DtaHashPwd` used the polished serial number string returned by `getSerialNum()` and took 20 bytes from it:

```cpp
serNum = d->getSerialNum();
vector<uint8_t> salt(serNum, serNum + 20);
```

This is from the tagged `1.20.0` version of `Common/DtaHashPwd.cpp`.

### Current `HEAD`

Current `HEAD` uses `getPasswordSalt()` instead:

```cpp
vector<uint8_t> salt(d->getPasswordSalt());
```

Relevant current file:

- [Common/DtaHashPwd.cpp](/home/blimpan/projects/sedutil/Common/DtaHashPwd.cpp:129)

`getPasswordSalt()` is implemented here:

- [Common/DtaDev.cpp](/home/blimpan/projects/sedutil/Common/DtaDev.cpp:158)

That value comes from `passwordSalt`, which is populated from the raw ATA IDENTIFY serial bytes before the normal serial polishing:

- [Common/ParseATIdentify.cpp](/home/blimpan/projects/sedutil/Common/ParseATIdentify.cpp:46)

The structure comment also describes this as a preserved copy of the original bytes:

- `Common/DtaStructures.h`: `passwordSalt[20]` is a copy of the first part of the serial before polishing

### Why This Matters

If the polished serial string used in `1.20.0` differs from the raw preserved serial bytes used in current `HEAD`, then PBKDF2 receives a different salt.

Different salt means different derived hash, even with:

- the same visible password
- the same PBKDF2 algorithm
- the same iteration count

This is enough to explain a mismatch between a `1.20.0` PBA and current `HEAD`.

## Important Change 2: Hex Translation Before Hashing

This is not a historical `1.20.0` vs `HEAD` change by itself; it is present in the current worktree diff.

Current `DtaHashPwd` now does:

```cpp
if (d->translate_req) {
    password_bytes = hex2data(password);
    ...
} else {
    password_bytes.assign(password, password + strnlen(password, 32));
}
```

and then hashes `password_bytes`.

Relevant current file:

- [Common/DtaHashPwd.cpp](/home/blimpan/projects/sedutil/Common/DtaHashPwd.cpp:106)

In `1.20.0`, hex translation was only used in the `no_hash_passwords` path. Normal hashed passwords were hashed from the plaintext `char *password`.

### Why This Matters

If `-t` or `-x` is used with the current worktree, the password may be hex-decoded first and then hashed as raw bytes. That can change the final derived value compared with `1.20.0`, where hashed mode used the plaintext characters directly.

If you are not using `-t` or `-x`, this part is probably not the cause of the mismatch.

## Relevance To `--prepareForS3Sleep`

The new S3 path computes the password material with:

```cpp
DtaHashPwd(hash, password, this);
```

and then strips the two-byte OPAL token header before sending the value to the Linux kernel:

- [Common/DtaDev.cpp](/home/blimpan/projects/sedutil/Common/DtaDev.cpp:626)

So `--prepareForS3Sleep` is directly dependent on the current `DtaHashPwd` behavior.

That means:

- if your PBA expects the `1.20.0` derivation, and
- `--prepareForS3Sleep` uses current `HEAD` derivation,

then the saved key material may not match what the PBA expects on resume.

## Practical Result

If you entered a normal plaintext password:

- the most likely incompatibility is the salt change from polished serial bytes in `1.20.0` to `passwordSalt` in current `HEAD`

If you entered a hex-encoded password using `-t` or `-x`:

- your local diff may also change the derived value because translation now happens before hashing

## Bottom Line

There is no evidence here that the PBKDF2 algorithm changed from SHA-1 to something else, or that the iteration count changed in the normal path.

There is clear evidence that the hash input changed, especially the salt source, and that is sufficient to require a different derived password value between `sedutil 1.20.0` and the current code.

## Reference Points

Current worktree:

- [Common/DtaHashPassword.cpp](/home/blimpan/projects/sedutil/Common/DtaHashPassword.cpp:41)
- [Common/DtaHashPwd.cpp](/home/blimpan/projects/sedutil/Common/DtaHashPwd.cpp:102)
- [Common/DtaDev.cpp](/home/blimpan/projects/sedutil/Common/DtaDev.cpp:158)
- [Common/DtaDev.cpp](/home/blimpan/projects/sedutil/Common/DtaDev.cpp:626)
- [Common/ParseATIdentify.cpp](/home/blimpan/projects/sedutil/Common/ParseATIdentify.cpp:46)

Historical reference:

- Git tag: `1.20.0`
- File examined: `Common/DtaHashPwd.cpp` from tag `1.20.0`
