pub fn Pool(comptime T: type, comptime items_per_block: usize) type {
    return struct {
        const entity_size = sized(@sizeOf(T));
        const block_size = entity_size * items_per_block;

        allocator: Allocator,

        blocks: std.ArrayListUnmanaged([]u8),
        block_index: usize,

        // If free made a whole block unused, keep it here.
        spare_block: std.ArrayListUnmanaged([]u8),

        pub const Self = @This();

        pub fn init(gpa: Allocator) Allocator.Error!Self {
            var pool: Self = .{
                .allocator = gpa,
                .blocks = .empty,
                .block_index = 0,
                .spare_block = .empty,
            };
            const new_block = try gpa.alloc(u8, block_size);
            errdefer gpa.free(new_block);
            try pool.blocks.append(gpa, new_block);
            try pool.spare_block.ensureTotalCapacity(gpa, pool.blocks.items.len);
            return pool;
        }

        pub fn deinit(self: *Self) void {
            for (self.blocks.items) |block| {
                self.allocator.free(block);
            }
            self.blocks.deinit(self.allocator);
            for (self.spare_block.items) |block| {
                self.allocator.free(block);
            }
            self.spare_block.deinit(self.allocator);
        }

        pub fn count(self: *const Self) usize {
            return (self.blocks.items.len * block_size / entity_size) -
                ((block_size - self.block_index) / entity_size);
        }

        pub fn alloc(self: *Self) Allocator.Error!*T {
            if (self.block_index == block_size) {
                @branchHint(.unlikely);
                if (self.spare_block.items.len > 0) {
                    const spare = self.spare_block.swapRemove(self.spare_block.items.len - 1);
                    try self.blocks.append(self.allocator, spare);
                    self.block_index = 0;
                } else {
                    const new_block = try self.allocator.alloc(u8, block_size);
                    errdefer self.allocator.free(new_block);
                    try self.blocks.append(self.allocator, new_block);
                    try self.spare_block.ensureTotalCapacity(self.allocator, self.blocks.items.len);
                    self.block_index = 0;
                }
            }
            const block = self.blocks.last().?;
            const entity: *T = @as(*T, @ptrCast(@alignCast(block.ptr + self.block_index)));
            self.block_index += entity_size;
            entity.* = undefined;
            return entity;
        }

        // The final last allocated item may be freed.
        pub fn free(self: *Self, item: *T) void {
            const block = self.blocks.last().?;
            if (self.block_index > 0) {
                const last: *T = @as(*T, @ptrCast(@alignCast(block.ptr + self.block_index - entity_size)));
                if (item == last) {
                    self.block_index -= entity_size;
                }
                return;
            }
            if (self.blocks.items.len == 1) {
                return;
            } else if (self.blocks.items.len > 1) {
                const removed = self.blocks.swapRemove(self.blocks.items.len - 1);
                self.spare_block.appendAssumeCapacity(removed);
                self.block_index = block_size - entity_size;
            } else if (self.blocks.items.len == 0) {
                unreachable;
            }
        }

        pub fn iterator(self: *const Self) Iterator {
            return .{
                .blocks = self.blocks.items,
                .last_block_index = self.block_index,
                .current_block = 0,
                .current_block_index = 0,
            };
        }

        pub const Iterator = struct {
            blocks: [][]u8,
            last_block_index: usize,
            current_block: usize,
            current_block_index: usize,

            pub fn next(self: *@This()) ?*T {
                if (self.blocks.len == 0) return null;
                const last_block = self.blocks.len - 1;
                if (self.current_block > last_block)
                    return null;
                if (self.current_block == last_block) {
                    if (self.current_block_index == self.last_block_index) {
                        self.current_block_index = 0;
                        self.current_block += 1;
                        return null;
                    }
                }
                const entity: *T = @as(*T, @ptrCast(@alignCast(self.blocks[self.current_block].ptr + self.current_block_index)));
                self.current_block_index += entity_size;
                if (self.current_block_index == block_size) {
                    self.current_block_index = 0;
                    self.current_block += 1;
                }
                return entity;
            }
        };
    };
}

/// Round up entity size to size of
pub fn sized(n: usize) usize {
    const s = @sizeOf(usize);
    const round = (n / s) * s;
    if (round == n) return n;
    return round + s;
}

/// Sample struct for test cases
const Sample = struct {
    a: u8 = 1,
    b: u16 = 2,
};

test "alloc" {
    var pool: Pool(Sample, 4) = try .init(std.testing.allocator);
    defer pool.deinit();
    try expectEqual(0, pool.block_index);
    try expectEqual(0, pool.count());
    var item1 = try pool.alloc();
    item1.a = 5;
    try expectEqual(1, pool.count());
    try expectEqual(sized(@sizeOf(Sample)), pool.block_index);
    try expectEqual(5, pool.blocks.items[0][0 + 2]);
    var item2 = try pool.alloc();
    item2.a = 6;
    try expectEqual(2, pool.count());
    try expectEqual(6, pool.blocks.items[0][sized(@sizeOf(Sample)) + 2]);
    try expectEqual(sized(@sizeOf(Sample)) * 2, pool.block_index);
    _ = try pool.alloc();
    _ = try pool.alloc();
    try expectEqual(4, pool.count());
    try expectEqual(sized(@sizeOf(Sample)) * 4, pool.block_index);
    var item5 = try pool.alloc();
    item5.a = 7;
    try expectEqual(5, pool.count());
    try expectEqual(7, pool.blocks.items[1][0 + 2]);
    try expectEqual(sized(@sizeOf(Sample)), pool.block_index);
}

test "free" {
    var pool: Pool(Sample, 3) = try .init(std.testing.allocator);
    defer pool.deinit();

    var a = try pool.alloc();
    a.a = 1;
    var i = pool.iterator();
    try expectEqual(1, i.next().?.a);
    try expectEqual(null, i.next());

    pool.free(a);
    i = pool.iterator();
    try expectEqual(null, i.next());

    a = try pool.alloc();
    a.a = 1;
    var b = try pool.alloc();
    b.a = 2;
    var c = try pool.alloc();
    c.a = 3;
    var d = try pool.alloc();
    d.a = 4;
    var e = try pool.alloc();
    e.a = 5;
    var f = try pool.alloc();
    f.a = 6;
    var g = try pool.alloc();
    g.a = 7;

    try expectEqual(7, testCountIterator(&pool));
    pool.free(e);
    pool.free(b);
    try expectEqual(7, testCountIterator(&pool));
    pool.free(g);
    try expectEqual(6, testCountIterator(&pool));
    pool.free(f);
    pool.free(f);
    try expectEqual(5, testCountIterator(&pool));
    pool.free(e);
    try expectEqual(4, testCountIterator(&pool));
    pool.free(d);
    try expectEqual(3, testCountIterator(&pool));
    pool.free(c);
    try expectEqual(2, testCountIterator(&pool));
    pool.free(b);
    try expectEqual(1, testCountIterator(&pool));
    pool.free(a);
    try expectEqual(0, testCountIterator(&pool));
    pool.free(a);
    try expectEqual(0, testCountIterator(&pool));
}

fn testCountIterator(pool: anytype) usize {
    var count: usize = 0;
    var i = pool.iterator();
    while (i.next() != null) {
        count += 1;
    }
    return count;
}

test "reuse_after_free" {
    var pool: Pool(Sample, 3) = try .init(std.testing.allocator);
    defer pool.deinit();

    var a = try pool.alloc();
    a.a = 1;
    var b = try pool.alloc();
    b.a = 2;
    var c = try pool.alloc();
    c.a = 3;
    try expectEqual(0, pool.spare_block.items.len);
    try expectEqual(1, pool.blocks.items.len);
    var d = try pool.alloc();
    d.a = 4;
    try expectEqual(2, pool.blocks.items.len);
    try expectEqual(0, pool.spare_block.items.len);
    pool.free(d);
    try expectEqual(0, pool.spare_block.items.len);
    pool.free(c);
    try expectEqual(1, pool.spare_block.items.len);
    c = try pool.alloc();
    c.a = 3;
    try expectEqual(1, pool.blocks.items.len);
    try expectEqual(1, pool.spare_block.items.len);
    d = try pool.alloc();
    d.a = 4;
    try expectEqual(2, pool.blocks.items.len);
    try expectEqual(0, pool.spare_block.items.len);
}

test "iterator" {
    var pool: Pool(Sample, 3) = try .init(std.testing.allocator);
    defer pool.deinit();

    var a = try pool.alloc();
    a.a = 1;

    var i = pool.iterator();
    try expectEqual(1, i.next().?.a);
    try expectEqual(null, i.next());
    try expectEqual(null, i.next());

    a = try pool.alloc();
    a.a = 2;

    i = pool.iterator();
    try expectEqual(1, i.next().?.a);
    try expectEqual(2, i.next().?.a);
    try expectEqual(null, i.next());
    try expectEqual(null, i.next());

    a = try pool.alloc();
    a.a = 3;

    i = pool.iterator();
    try expectEqual(1, i.next().?.a);
    try expectEqual(2, i.next().?.a);
    try expectEqual(3, i.next().?.a);
    try expectEqual(null, i.next());
    try expectEqual(null, i.next());

    a = try pool.alloc();
    a.a = 4;

    i = pool.iterator();
    try expectEqual(1, i.next().?.a);
    try expectEqual(2, i.next().?.a);
    try expectEqual(3, i.next().?.a);
    try expectEqual(4, i.next().?.a);
    try expectEqual(null, i.next());
    try expectEqual(null, i.next());

    a = try pool.alloc();
    a.a = 5;
    a = try pool.alloc();
    a.a = 6;
    a = try pool.alloc();
    a.a = 7;

    i = pool.iterator();
    try expectEqual(1, i.next().?.a);
    try expectEqual(2, i.next().?.a);
    try expectEqual(3, i.next().?.a);
    try expectEqual(4, i.next().?.a);
    try expectEqual(5, i.next().?.a);
    try expectEqual(6, i.next().?.a);
    try expectEqual(7, i.next().?.a);
    try expectEqual(null, i.next());
    try expectEqual(null, i.next());
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const expectEqual = std.testing.expectEqual;
