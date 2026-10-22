pub fn extend(dictionary: *Dictionary, lexeme: *Lexeme) error{ OutOfMemory, InvalidUtf8, WordTooLong }!void {
    try equalize(dictionary, lexeme, "A-NSN", "A-ASN");
    try equalize(dictionary, lexeme, "A-NPN", "A-APN");

    // Feminine alpha endings have a map, i.e. οἰκία|οἰκίας->οἰκίας
    // But the accent can be different. tbc
    //var n: praxis.Normaliser.Keywords(praxis.max_word_size) = .empty;
    //const value = try n.normalise(lexeme.word);
    //if (lexeme.hasFeminineNoun()) {
    //    if (std.mem.endsWith(u8, value.unaccented, "α")) {
    //        try equalize(dictionary, lexeme, "N-GSF", "N-APF");
    //        try equalize(dictionary, lexeme, "N-GSF", "N-APF");
    //    }
    //}

    if (lexeme.hasMasculineAdjective() and lexeme.hasNeuterAdjective()) {
        try equalize(dictionary, lexeme, "A-GPN", "A-GPM");
        try equalize(dictionary, lexeme, "A-DPN", "A-DPM");
        try equalize(dictionary, lexeme, "A-GSN", "A-GSM");
        try equalize(dictionary, lexeme, "A-DSN", "A-DSM");
    }

    try equalize(dictionary, lexeme, "V-IAI-1S", "V-IAI-3P");
    try equalize(dictionary, lexeme, "V-PEI-1S", "V-PMI-1S");
    try equalize(dictionary, lexeme, "V-PPI-1S", "V-PMI-1S");
    try equalize(dictionary, lexeme, "V-PEI-2S", "V-PMI-2S");
    try equalize(dictionary, lexeme, "V-PPI-2S", "V-PMI-2S");
    try equalize(dictionary, lexeme, "V-PEI-3S", "V-PMI-3S");
    try equalize(dictionary, lexeme, "V-PPI-3S", "V-PMI-3S");
    try equalize(dictionary, lexeme, "V-PEI-2S", "V-PAS-3S");
    try equalize(dictionary, lexeme, "V-PPI-2S", "V-PAS-3S");
    try equalize(dictionary, lexeme, "V-PMI-2S", "V-PAS-3S");
    try equalize(dictionary, lexeme, "V-PEM-2P", "V-PMM-2P");
    try equalize(dictionary, lexeme, "V-PEM-2P", "V-PPM-2P");
    try equalize(dictionary, lexeme, "V-PMM-2P", "V-PPI-2P");
    try equalize(dictionary, lexeme, "V-PEM-2S", "V-PMM-2S");
    try equalize(dictionary, lexeme, "V-PEM-2S", "V-PPM-2S");
    try equalize(dictionary, lexeme, "V-PAP-NSN", "V-PAP-ASN");
    try equalize(dictionary, lexeme, "V-AAP-NSN", "V-AAP-ASN");
    try equalize(dictionary, lexeme, "V-PAP-NPN", "V-PAP-APN");
    try equalize(dictionary, lexeme, "V-AAP-NPN", "V-AAP-APN");
    try equalize(dictionary, lexeme, "V-PAP-GPM", "V-PAP-GPN");
    try equalize(dictionary, lexeme, "V-AAP-GPM", "V-AAP-GPN");
    try equalize(dictionary, lexeme, "V-PAP-DSM", "V-PAP-DSN");
    try equalize(dictionary, lexeme, "V-AAP-DSM", "V-AAP-DSN");
    try equalize(dictionary, lexeme, "V-PAP-GSM", "V-PAP-GSN");
    try equalize(dictionary, lexeme, "V-AAP-GSM", "V-AAP-GSN");
    try equalize(dictionary, lexeme, "V-PMP-NSN", "V-PMP-ASN");
    try equalize(dictionary, lexeme, "V-PPP-NSN", "V-PMP-ASN");
    try equalize(dictionary, lexeme, "V-PEP-NSN", "V-PMP-ASN");
    try equalize(dictionary, lexeme, "V-PEP-ASN", "V-PMP-ASN");
    try equalize(dictionary, lexeme, "V-PEP-ASN", "V-PPP-ASN");
    try equalize(dictionary, lexeme, "V-PEP-ASN", "V-PMP-ASN");
    try equalize(dictionary, lexeme, "V-PPP-ASN", "V-PMP-NSN");
    try equalize(dictionary, lexeme, "V-PPP-ASN", "V-PMP-ASN");
    try equalize(dictionary, lexeme, "V-PEP-NPN", "V-PPP-NPN");
    try equalize(dictionary, lexeme, "V-PEP-NPN", "V-PMP-NPN");
    try equalize(dictionary, lexeme, "V-PEP-APN", "V-PPP-APN");
    try equalize(dictionary, lexeme, "V-PEP-APN", "V-PMP-APN");
    try equalize(dictionary, lexeme, "V-PMP-NPN", "V-PPP-NPN");
    try equalize(dictionary, lexeme, "V-PPP-NPN", "V-PMP-NPN");
    try equalize(dictionary, lexeme, "V-PMP-NPN", "V-PMP-APN");
    try equalize(dictionary, lexeme, "V-PMP-APN", "V-PMP-NPN");
    try equalize(dictionary, lexeme, "V-PPP-NPN", "V-PPP-APN");
    try equalize(dictionary, lexeme, "V-PPP-APN", "V-PPP-NPN");
}

fn equalize(
    dictionary: *Dictionary,
    lexeme: *Lexeme,
    comptime left: []const u8,
    comptime right: []const u8,
) error{OutOfMemory}!void {
    const left_parsing: Parsing = Byzantine.parse(left) catch unreachable;
    const right_parsing: Parsing = Byzantine.parse(right) catch unreachable;

    var left_form: ?*Form = null;
    var right_form: ?*Form = null;

    for (lexeme.forms.items) |form| {
        if (form.parsing == left_parsing) left_form = form;
        if (form.parsing == right_parsing) right_form = form;
    }

    if (left_form == null and right_form == null)
        return;

    if (left_form != null and right_form != null) {
        if (!std.mem.eql(u8, left_form.?.word, right_form.?.word)) {
            warn("{s}/{s} != {s}/{s}", .{
                left,
                left_form.?.word,
                right,
                right_form.?.word,
            });
        }
        return;
    }

    if (left_form == null) {
        var form: *Form = try dictionary.forms.alloc();
        form.parsing = left_parsing;
        form.word = try dictionary.allocator.dupe(u8, right_form.?.word);
        form.lexeme = right_form.?.lexeme;
        form.preferred = right_form.?.preferred;
        form.incorrect = right_form.?.incorrect;
        form.glosses = .empty;
        form.references = .empty;
        form.uid = dictionary.generateUniqueUid();
        try dictionary.by_form_uid.put(dictionary.allocator, form.uid, form);
        try lexeme.forms.append(dictionary.allocator, form);
        info("add form {s} parsing {s} uid {d}", .{ form.word, left, form.uid });
        return;
    }

    if (right_form == null) {
        var form: *Form = try dictionary.forms.alloc();
        form.parsing = left_parsing;
        form.word = try dictionary.allocator.dupe(u8, left_form.?.word);
        form.lexeme = left_form.?.lexeme;
        form.preferred = left_form.?.preferred;
        form.incorrect = left_form.?.incorrect;
        form.glosses = .empty;
        form.references = .empty;
        form.uid = dictionary.generateUniqueUid();
        try dictionary.by_form_uid.put(dictionary.allocator, form.uid, form);
        try lexeme.forms.append(dictionary.allocator, form);
        info("add form {s} parsing {s} uid {d}", .{ form.word, left, form.uid });
        return;
    }
}

test "extend" {
    var dictionary: *Dictionary = try Dictionary.create(std.testing.allocator);
    defer dictionary.destroy();

    const data =
        \\δράκων|el|800000|Noun|ὁ|-οντος|1404|δράκ|en:dragon:large serpent#ru:дракон:большой змей#zh:龍:大蛇#es:dragón:serpiente grande||animal|
        \\  δράκων|N-NSM|false|700000||byz#Revelation 12:3 11,kjtr#Revelation 12:3 10,sbl#Revelation 12:3 10
        \\  δράκοντα|N-ASM|false|700001|en:the sneaky|byz#Revelation 20:2 3,kjtr#Revelation 20:2 3
        \\λύω|el|800001|Verb|||3089|λύ|en:untie:release:loose#ru:развязывать:освобождать:разрушать#zh:解開:釋放:放開#es:desato:suelto|||
        \\  λύω|V-PAI-1S|false|700002|en:I untie:I release:I loose|
        \\  λύεις|V-PAI-2S|false|700003|en:You untie:You release|
        \\  λύει|V-PAI-3S|false|700004|en:You untie:You release|
        \\  λύε|V-PAI-3S|false|700009||
        \\  λύ|V-PAI-3S|false|700008||
        \\δένδρον|el|11352027|Noun|τό|-ου|1186|δένδρ|en:tree#zh:樹:樹木#ru:дерево#es:árbol||object, garden|
        \\  δένδρον|N-NSN|false|8222586|en:tree#es:árbol|
        \\  δένδρου|N-GSN|false|14894887|en:tree|
        \\  δένδρῳ|N-DSN|false|6558579|en:tree|
        \\  δένδρα|N-NPN|false|15002325|en:trees|
        \\  δένδρων|N-GPN|false|9872701|en:trees|
        \\  δένδροις|N-DSN|false|153632|en:tree|
        \\μέλας|el|15684547|Adjective|||3189|μέλ|en:black:ink#zh:黑色#es:negro|μέλας,-αινα,-αν|colour|
        \\  μέλας|A-NSM|false|1595270|en:black:ink|
        \\  μέλαν|A-ASM|true|4180610|en:black:ink|
        \\  μέλανος|A-GSM|false|5782097|en:black|
        \\  μέλανι|A-DSM|false|5438382|en:black|
        \\  μέλανες|A-NPM|false|6568758|en:black|
        \\  μέλανας|A-APM|false|1705397|en:black|
        \\  μέλασι|A-GPM|false|6105319|en:black|
        \\  μελάνων|A-DPM|false|6832086|en:black|
        \\  μέλαινα|A-NSF|false|8014446|en:black:ink|
        \\  μέλαιναν|A-ASF|false|6921504|en:black:ink|
        \\  μελαίνης|A-GSF|false|15138369|en:black|
        \\  μελαίνῃ|A-DSF|false|819012|en:black|
        \\  μέλαιναι|A-NPF|false|7374103|en:black|
        \\  μελαίνας|A-APF|false|7316696|en:black|
        \\  μελαινῶν|A-GPF|false|6256861|en:black|
        \\  μελαίναις|A-DPF|false|5630500|en:black|
        \\  μέλαν|A-NSN|false|12733832|en:black|
        \\  μέλανος|A-GSN|false|5078796|en:black|
        \\  μέλανι|A-DSN|false|7328017|en:black|
        \\  μέλανα|A-APN|false|8503699|en:black|
        \\  μελάνων|A-GPN|false|4881319|en:black|
        \\  μέλασιν|A-DPN|false|16091289|en:black|
    ;
    try dictionary.loadTextData(std.testing.allocator, data);

    {
        const result = try dictionary.by_lexeme.lookup("μέλας");
        const lexeme = result.?.first();
        try expectEqual(22, lexeme.?.forms.items.len);
        try expect(lexeme.?.formByParsing(try Byzantine.parse("A-ASN")) == null);
        try expect(lexeme.?.formByParsing(try Byzantine.parse("A-NPN")) == null);
        try extend(dictionary, lexeme.?);
        try expectEqual(24, lexeme.?.forms.items.len);
        try expect(lexeme.?.formByParsing(try Byzantine.parse("A-NSN")) != null);
        try expect(lexeme.?.formByParsing(try Byzantine.parse("A-APN")) != null);
    }
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const warn = std.log.warn;
const info = std.log.info;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const praxis = @import("praxis.zig");
const Dictionary = praxis.Dictionary;
const Normaliser = praxis.Normaliser.Keywords(praxis.max_word_size);
const Lexeme = @import("praxis.zig").Lexeme;
const Form = @import("praxis.zig").Form;
const Parsing = @import("praxis.zig").Parsing;
const Byzantine = @import("Byzantine.zig").Byzantine;
