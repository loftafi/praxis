//! A simple random number generator useful for games that do not need
//! cryptographically secure random numbers.

var seeded: bool = false;
var value: usize = 99;

/// Return a number zero or greater but less than the `limit`. Call `seed()`
/// first if you do not want a predictable sequence of numbers.
///
/// This is _not_ cryptographically secure.
pub fn random(limit: usize) usize {
    if (limit == 0) {
        return 0;
    }
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    return value % limit;
}

/// Return a random u24 value. Call `seed()` first if you do not want a
/// predictable number sequence.
///
/// This is _not_ cryptographically secure.
pub inline fn random_u24() u24 {
    return @intCast(random(std.math.maxInt(u24)));
}

/// Return a random u64 value. Call `seed()` first if you do not want a
/// predictable number sequence.
///
/// This is _not_ cryptographically secure.
pub inline fn random_u64() u64 {
    return @as(u64, random(std.math.maxInt(u64)));
}

/// Seed the random number generator with the current time
pub fn seed() void {
    if (seeded) return;
    value = @intCast(std.time.milliTimestamp());
}

const std = @import("std");
