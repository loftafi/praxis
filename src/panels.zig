//! Group a set of word forms into a set of tables of grammatical forms.

const Self = @This();

lexeme: *Lexeme,
tables: std.ArrayList(Panel),

pub fn create(allocator: std.mem.Allocator) !*Self {
    var p = try allocator.create(Self);
    p.init(allocator);
    return p;
}

pub fn destroy(self: *Self) void {
    const allocator = self.tables.allocator;
    self.tables.deinit();
    allocator.destroy(self);
}

pub fn init(self: *Self, allocator: std.mem.Allocator) void {
    self.tables = std.ArrayList(Panel).init(allocator);
}

pub fn deinit(self: *Panel) void {
    self.tables.deinit();
}

pub fn setLexeme(self: *Self, lexeme: *Lexeme) void {
    self.lexeme = lexeme;
    self.tables.clearRetainingCapacity();
}

pub const Panel = struct {
    title: []const u8 = "",
    subtitle: []const u8 = "",
    gender: Gender = .unknown,
    top: [5]?*Form = [_]?*Form{ null, null, null, null, null },
    bottom: [5]?*Form = [_]?*Form{ null, null, null, null, null },
    count: u8,

    pub fn hasData(self: *Panel) bool {
        return self.top[0] != null or self.top[1] != null or
            self.top[2] != null or self.top[3] != null or self.top[4] != null or
            self.bottom[0] != null or self.bottom[1] != null or self.bottom[2] != null or
            self.bottom[3] != null or self.bottom[4] != null;
    }
};

pub fn panels(self: *Self) ![]Panel {
    std.log.debug("panels for {s}", .{self.lexeme.word});
    const forms = self.lexeme.forms.items;
    self.tables.clearRetainingCapacity();

    if (self.lexeme.pos.part_of_speech == .verb) {
        var panel = Panel{ .title = "Present", .subtitle = "Active", .count = 3 };
        panel.top[0] = ff(forms, .verb, .present, .active, .indicative, .first, .singular);
        panel.top[1] = ff(forms, .verb, .present, .active, .indicative, .second, .singular);
        panel.top[2] = ff(forms, .verb, .present, .active, .indicative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .present, .active, .indicative, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .present, .active, .indicative, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .present, .active, .indicative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Future", .subtitle = "Active", .count = 3 };
        panel.top[0] = ff(forms, .verb, .future, .active, .indicative, .first, .singular);
        panel.top[1] = ff(forms, .verb, .future, .active, .indicative, .second, .singular);
        panel.top[2] = ff(forms, .verb, .future, .active, .indicative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .future, .active, .indicative, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .future, .active, .indicative, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .future, .active, .indicative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }
        panel = Panel{ .title = "Imperfect", .subtitle = "Active", .count = 3 };
        panel.top[0] = ff(forms, .verb, .imperfect, .active, .indicative, .first, .singular);
        panel.top[1] = ff(forms, .verb, .imperfect, .active, .indicative, .second, .singular);
        panel.top[2] = ff(forms, .verb, .imperfect, .active, .indicative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .imperfect, .active, .indicative, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .imperfect, .active, .indicative, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .imperfect, .active, .indicative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }
        panel = Panel{ .title = "Aorist", .subtitle = "Active", .count = 3 };
        panel.top[0] = ff(forms, .verb, .aorist, .active, .indicative, .first, .singular);
        panel.top[1] = ff(forms, .verb, .aorist, .active, .indicative, .second, .singular);
        panel.top[2] = ff(forms, .verb, .aorist, .active, .indicative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .aorist, .active, .indicative, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .aorist, .active, .indicative, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .aorist, .active, .indicative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }
        panel = Panel{ .title = "Perfect", .subtitle = "Active", .count = 3 };
        panel.top[0] = ff(forms, .verb, .perfect, .active, .indicative, .first, .singular);
        panel.top[1] = ff(forms, .verb, .perfect, .active, .indicative, .second, .singular);
        panel.top[2] = ff(forms, .verb, .perfect, .active, .indicative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .perfect, .active, .indicative, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .perfect, .active, .indicative, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .perfect, .active, .indicative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Pluperfect", .subtitle = "Active", .count = 3 };
        panel.top[0] = ff(forms, .verb, .pluperfect, .active, .indicative, .first, .singular);
        panel.top[1] = ff(forms, .verb, .pluperfect, .active, .indicative, .second, .singular);
        panel.top[2] = ff(forms, .verb, .pluperfect, .active, .indicative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .pluperfect, .active, .indicative, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .pluperfect, .active, .indicative, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .pluperfect, .active, .indicative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Subjunctive", .subtitle = "Present", .count = 3 };
        panel.top[0] = ff(forms, .verb, .present, .active, .subjunctive, .first, .singular);
        panel.top[1] = ff(forms, .verb, .present, .active, .subjunctive, .second, .singular);
        panel.top[2] = ff(forms, .verb, .present, .active, .subjunctive, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .present, .active, .subjunctive, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .present, .active, .subjunctive, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .present, .active, .subjunctive, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Subjunctive", .subtitle = "Aorist", .count = 3 };
        panel.top[0] = ff(forms, .verb, .aorist, .active, .subjunctive, .first, .singular);
        panel.top[1] = ff(forms, .verb, .aorist, .active, .subjunctive, .second, .singular);
        panel.top[2] = ff(forms, .verb, .aorist, .active, .subjunctive, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .aorist, .active, .subjunctive, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .aorist, .active, .subjunctive, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .aorist, .active, .subjunctive, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Subjunctive", .subtitle = "Present Mid", .count = 3 };
        panel.top[0] = ff(forms, .verb, .present, .middle, .subjunctive, .first, .singular);
        panel.top[1] = ff(forms, .verb, .present, .middle, .subjunctive, .second, .singular);
        panel.top[2] = ff(forms, .verb, .present, .middle, .subjunctive, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .present, .middle, .subjunctive, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .present, .middle, .subjunctive, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .present, .middle, .subjunctive, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Subjunctive", .subtitle = "Aorist Mid", .count = 3 };
        panel.top[0] = ff(forms, .verb, .aorist, .middle, .subjunctive, .first, .singular);
        panel.top[1] = ff(forms, .verb, .aorist, .middle, .subjunctive, .second, .singular);
        panel.top[2] = ff(forms, .verb, .aorist, .middle, .subjunctive, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .aorist, .middle, .subjunctive, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .aorist, .middle, .subjunctive, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .aorist, .middle, .subjunctive, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Subjunctive", .subtitle = "Present Psv", .count = 3 };
        panel.top[0] = ff(forms, .verb, .present, .passive, .subjunctive, .first, .singular);
        panel.top[1] = ff(forms, .verb, .present, .passive, .subjunctive, .second, .singular);
        panel.top[2] = ff(forms, .verb, .present, .passive, .subjunctive, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .present, .passive, .subjunctive, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .present, .passive, .subjunctive, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .present, .passive, .subjunctive, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Subjunctive", .subtitle = "Aorist Psv", .count = 3 };
        panel.top[0] = ff(forms, .verb, .aorist, .passive, .subjunctive, .first, .singular);
        panel.top[1] = ff(forms, .verb, .aorist, .passive, .subjunctive, .second, .singular);
        panel.top[2] = ff(forms, .verb, .aorist, .passive, .subjunctive, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .aorist, .passive, .subjunctive, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .aorist, .passive, .subjunctive, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .aorist, .passive, .subjunctive, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Infinitive", .subtitle = "", .count = 2 };
        panel.top[0] = ff(forms, .verb, .present, .active, .infinitive, .unknown, .unknown);
        panel.top[1] = ff(forms, .verb, .aorist, .active, .infinitive, .unknown, .unknown);
        panel.bottom[0] = ff(forms, .verb, .present, .passive, .infinitive, .unknown, .unknown);
        panel.bottom[1] = ff(forms, .verb, .aorist, .passive, .infinitive, .unknown, .unknown);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Present", .subtitle = "Passive", .count = 3 };
        panel.top[0] = ff(forms, .verb, .present, .passive, .indicative, .first, .singular);
        panel.top[1] = ff(forms, .verb, .present, .passive, .indicative, .second, .singular);
        panel.top[2] = ff(forms, .verb, .present, .passive, .indicative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .present, .passive, .indicative, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .present, .passive, .indicative, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .present, .passive, .indicative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Future", .subtitle = "Middle", .count = 3 };
        panel.top[0] = ff(forms, .verb, .future, .middle, .indicative, .first, .singular);
        panel.top[1] = ff(forms, .verb, .future, .middle, .indicative, .second, .singular);
        panel.top[2] = ff(forms, .verb, .future, .middle, .indicative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .future, .middle, .indicative, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .future, .middle, .indicative, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .future, .middle, .indicative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Future", .subtitle = "Passive", .count = 3 };
        panel.top[0] = ff(forms, .verb, .future, .passive, .indicative, .first, .singular);
        panel.top[1] = ff(forms, .verb, .future, .passive, .indicative, .second, .singular);
        panel.top[2] = ff(forms, .verb, .future, .passive, .indicative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .future, .passive, .indicative, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .future, .passive, .indicative, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .future, .passive, .indicative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Imperfect", .subtitle = "Passive", .count = 3 };
        panel.top[0] = ff(forms, .verb, .imperfect, .passive, .indicative, .first, .singular);
        panel.top[1] = ff(forms, .verb, .imperfect, .passive, .indicative, .second, .singular);
        panel.top[2] = ff(forms, .verb, .imperfect, .passive, .indicative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .imperfect, .passive, .indicative, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .imperfect, .passive, .indicative, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .imperfect, .passive, .indicative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Aorist", .subtitle = "Passive", .count = 3 };
        panel.top[0] = ff(forms, .verb, .aorist, .passive, .indicative, .first, .singular);
        panel.top[1] = ff(forms, .verb, .aorist, .passive, .indicative, .second, .singular);
        panel.top[2] = ff(forms, .verb, .aorist, .passive, .indicative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .aorist, .passive, .indicative, .first, .plural);
        panel.bottom[1] = ff(forms, .verb, .aorist, .passive, .indicative, .second, .plural);
        panel.bottom[2] = ff(forms, .verb, .aorist, .passive, .indicative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Imperative", .subtitle = "Present", .count = 2 };
        panel.top[0] = ff(forms, .verb, .present, .active, .imperative, .second, .singular);
        panel.top[1] = ff(forms, .verb, .present, .active, .imperative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .present, .active, .imperative, .second, .plural);
        panel.bottom[1] = ff(forms, .verb, .present, .active, .imperative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Imperative", .subtitle = "Aorist", .count = 2 };
        panel.top[0] = ff(forms, .verb, .aorist, .active, .imperative, .second, .singular);
        panel.top[1] = ff(forms, .verb, .aorist, .active, .imperative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .aorist, .active, .imperative, .second, .plural);
        panel.bottom[1] = ff(forms, .verb, .aorist, .active, .imperative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Imperative", .subtitle = "Present Psv", .count = 2 };
        panel.top[0] = ff(forms, .verb, .present, .passive, .imperative, .second, .singular);
        panel.top[1] = ff(forms, .verb, .present, .passive, .imperative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .present, .passive, .imperative, .second, .plural);
        panel.bottom[1] = ff(forms, .verb, .present, .passive, .imperative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }

        panel = Panel{ .title = "Imperative", .subtitle = "Aorist Psv", .count = 2 };
        panel.top[0] = ff(forms, .verb, .aorist, .passive, .imperative, .second, .singular);
        panel.top[1] = ff(forms, .verb, .aorist, .passive, .imperative, .third, .singular);
        panel.bottom[0] = ff(forms, .verb, .aorist, .passive, .imperative, .second, .plural);
        panel.bottom[1] = ff(forms, .verb, .aorist, .passive, .imperative, .third, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }
    }

    if (self.lexeme.pos.part_of_speech == .noun or (self.lexeme.pos.part_of_speech == .proper_noun and !self.lexeme.pos.indeclinable)) {
        var panel = Panel{ .title = "Masculine", .subtitle = "", .count = 4 };
        panel.gender = .masculine;
        panel.top[0] = nf(forms, .noun, .nominative, .masculine, .singular);
        panel.top[1] = nf(forms, .noun, .genitive, .masculine, .singular);
        panel.top[2] = nf(forms, .noun, .dative, .masculine, .singular);
        panel.top[3] = nf(forms, .noun, .accusative, .masculine, .singular);
        panel.bottom[0] = nf(forms, .noun, .nominative, .masculine, .plural);
        panel.bottom[1] = nf(forms, .noun, .genitive, .masculine, .plural);
        panel.bottom[2] = nf(forms, .noun, .dative, .masculine, .plural);
        panel.bottom[3] = nf(forms, .noun, .accusative, .masculine, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }
        panel = Panel{ .title = "Feminine", .subtitle = "", .count = 4 };
        panel.gender = .feminine;
        panel.top[0] = nf(forms, .noun, .nominative, .feminine, .singular);
        panel.top[1] = nf(forms, .noun, .genitive, .feminine, .singular);
        panel.top[2] = nf(forms, .noun, .dative, .feminine, .singular);
        panel.top[3] = nf(forms, .noun, .accusative, .feminine, .singular);
        panel.bottom[0] = nf(forms, .noun, .nominative, .feminine, .plural);
        panel.bottom[1] = nf(forms, .noun, .genitive, .feminine, .plural);
        panel.bottom[2] = nf(forms, .noun, .dative, .feminine, .plural);
        panel.bottom[3] = nf(forms, .noun, .accusative, .feminine, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }
        panel = Panel{ .title = "Neuter", .subtitle = "", .count = 4 };
        panel.gender = .neuter;
        panel.top[0] = nf(forms, .noun, .nominative, .neuter, .singular);
        panel.top[1] = nf(forms, .noun, .genitive, .neuter, .singular);
        panel.top[2] = nf(forms, .noun, .dative, .neuter, .singular);
        panel.top[3] = nf(forms, .noun, .accusative, .neuter, .singular);
        panel.bottom[0] = nf(forms, .noun, .nominative, .neuter, .plural);
        panel.bottom[1] = nf(forms, .noun, .genitive, .neuter, .plural);
        panel.bottom[2] = nf(forms, .noun, .dative, .neuter, .plural);
        panel.bottom[3] = nf(forms, .noun, .accusative, .neuter, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }
    }

    if (self.lexeme.pos.part_of_speech == .personal_pronoun) {
        std.log.debug("searching personal pronoun for {d}", .{self.lexeme.uid});
        if (self.lexeme.uid == 30314) {
            var panel = Panel{ .title = "Singular", .subtitle = "", .count = 4 };
            panel.top[0] = pp(forms, .personal_pronoun, .nominative, .singular, .first);
            panel.top[1] = pp(forms, .personal_pronoun, .accusative, .singular, .first);
            panel.top[2] = pp(forms, .personal_pronoun, .genitive, .singular, .first);
            panel.top[3] = pp(forms, .personal_pronoun, .dative, .singular, .first);
            if (panel.hasData()) {
                try self.tables.append(panel);
            }
            panel = Panel{ .title = "Plural", .subtitle = "", .count = 4 };
            panel.top[0] = pp(forms, .personal_pronoun, .nominative, .plural, .first);
            panel.top[1] = pp(forms, .personal_pronoun, .accusative, .plural, .first);
            panel.top[2] = pp(forms, .personal_pronoun, .genitive, .plural, .first);
            panel.top[3] = pp(forms, .personal_pronoun, .dative, .plural, .first);
            if (panel.hasData()) {
                try self.tables.append(panel);
            }
        }
        if (self.lexeme.uid == 96456) {
            var panel = Panel{ .title = "Singular", .subtitle = "", .count = 4 };
            panel.top[0] = pp(forms, .personal_pronoun, .nominative, .singular, .second);
            panel.top[1] = pp(forms, .personal_pronoun, .accusative, .singular, .second);
            panel.top[2] = pp(forms, .personal_pronoun, .genitive, .singular, .second);
            panel.top[3] = pp(forms, .personal_pronoun, .dative, .singular, .second);
            if (panel.hasData()) {
                try self.tables.append(panel);
            }
            panel = Panel{ .title = "Plural", .subtitle = "", .count = 4 };
            panel.top[0] = pp(forms, .personal_pronoun, .nominative, .plural, .second);
            panel.top[1] = pp(forms, .personal_pronoun, .accusative, .plural, .second);
            panel.top[2] = pp(forms, .personal_pronoun, .genitive, .plural, .second);
            panel.top[3] = pp(forms, .personal_pronoun, .dative, .plural, .second);
            if (panel.hasData()) {
                try self.tables.append(panel);
            }
        }
    }

    // Filter ajectives into panels, or words like adjectives.
    if (self.lexeme.pos.part_of_speech == .adjective or self.lexeme.uid == 17770 or self.lexeme.uid == 31602 or self.lexeme.uid == 75261) {
        const pos = self.lexeme.pos.part_of_speech;
        var panel = Panel{ .title = "Masculine", .subtitle = "", .count = 4 };
        panel.gender = .masculine;
        panel.top[0] = nf(forms, pos, .nominative, .masculine, .singular);
        panel.top[1] = nf(forms, pos, .genitive, .masculine, .singular);
        panel.top[2] = nf(forms, pos, .dative, .masculine, .singular);
        panel.top[3] = nf(forms, pos, .accusative, .masculine, .singular);
        panel.bottom[0] = nf(forms, pos, .nominative, .masculine, .plural);
        panel.bottom[1] = nf(forms, pos, .genitive, .masculine, .plural);
        panel.bottom[2] = nf(forms, pos, .dative, .masculine, .plural);
        panel.bottom[3] = nf(forms, pos, .accusative, .masculine, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }
        panel = Panel{ .title = "Feminine", .subtitle = "", .count = 4 };
        panel.gender = .feminine;
        panel.top[0] = nf(forms, pos, .nominative, .feminine, .singular);
        panel.top[1] = nf(forms, pos, .genitive, .feminine, .singular);
        panel.top[2] = nf(forms, pos, .dative, .feminine, .singular);
        panel.top[3] = nf(forms, pos, .accusative, .feminine, .singular);
        panel.bottom[0] = nf(forms, pos, .nominative, .feminine, .plural);
        panel.bottom[1] = nf(forms, pos, .genitive, .feminine, .plural);
        panel.bottom[2] = nf(forms, pos, .dative, .feminine, .plural);
        panel.bottom[3] = nf(forms, pos, .accusative, .feminine, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }
        panel = Panel{ .title = "Neuter", .subtitle = "", .count = 4 };
        panel.gender = .neuter;
        panel.top[0] = nf(forms, pos, .nominative, .neuter, .singular);
        panel.top[1] = nf(forms, pos, .genitive, .neuter, .singular);
        panel.top[2] = nf(forms, pos, .dative, .neuter, .singular);
        panel.top[3] = nf(forms, pos, .accusative, .neuter, .singular);
        panel.bottom[0] = nf(forms, pos, .nominative, .neuter, .plural);
        panel.bottom[1] = nf(forms, pos, .genitive, .neuter, .plural);
        panel.bottom[2] = nf(forms, pos, .dative, .neuter, .plural);
        panel.bottom[3] = nf(forms, pos, .accusative, .neuter, .plural);
        if (panel.hasData()) {
            try self.tables.append(panel);
        }
    }

    return self.tables.items;
}

/// voice must be active, middle, passive. Do not use other voice options.
pub fn ff(
    forms: []*Form,
    pos: PartOfSpeech,
    tense_form: TenseForm,
    voice: Voice,
    mood: Mood,
    person: Person,
    number: Number,
) ?*Form {
    for (forms) |form| {
        if (form.parsing.part_of_speech != pos) {
            continue;
        }
        if (form.parsing.tense_form != tense_form) {
            continue;
        }
        var v = form.parsing.voice;
        if (v == .passive_deponent) {
            v = .passive;
        }
        if (v == .middle_deponent) {
            v = .middle;
        }
        if (v == .middle_or_passive or v == .middle_or_passive_deponent) {
            if (voice == .middle) {
                v = .middle;
            }
            if (voice == .passive) {
                v = .passive;
            }
        }
        if (v != voice) {
            continue;
        }
        if (form.parsing.mood != mood) {
            continue;
        }
        if (form.parsing.person != person) {
            continue;
        }
        if (form.parsing.number != number) {
            continue;
        }
        return form;
    }
    return null;
}

pub fn nf(
    forms: []*Form,
    pos: PartOfSpeech,
    case: Case,
    gender: Gender,
    number: Number,
) ?*Form {
    for (forms) |form| {
        if (form.parsing.part_of_speech != pos) {
            continue;
        }
        if (form.parsing.case != case) {
            continue;
        }
        if (form.parsing.number != number) {
            continue;
        }
        if (form.parsing.gender != gender) {
            continue;
        }
        return form;
    }
    return null;
}

pub fn pp(
    forms: []*Form,
    pos: PartOfSpeech,
    case: Case,
    number: Number,
    person: Person,
) ?*Form {
    for (forms) |form| {
        const ref = switch (number) {
            .singular => TenseForm.ref_singular,
            .plural => TenseForm.ref_plural,
            else => TenseForm.unknown,
        };
        if (form.parsing.part_of_speech != pos) {
            continue;
        }
        if (form.parsing.case != case) {
            continue;
        }
        if (form.parsing.tense_form != ref) {
            continue;
        }
        if (form.parsing.person != person) {
            continue;
        }
        return form;
    }
    return null;
}

const std = @import("std");
const ArrayList = std.ArrayList;
const Lexeme = @import("lexeme.zig");
const PartOfSpeech = @import("parsing.zig").PartOfSpeech;
const Gender = @import("parsing.zig").Gender;
const Person = @import("parsing.zig").Person;
const TenseForm = @import("parsing.zig").TenseForm;
const Voice = @import("parsing.zig").Voice;
const Number = @import("parsing.zig").Number;
const Case = @import("parsing.zig").Case;
const Mood = @import("parsing.zig").Mood;
const Form = @import("form.zig");
