import gx
import strconv

enum TokenKind {
	lcbr
	rcbr
	labr
	rabr
	comma
        semicolon
	colon
        hex
        dec
        unit
	eof
	str
	ident
	unknown
}

struct Scanner {
mut:
	pos         int
	line        int = 1
	text        string
	inside_text bool
	tokens      []Token
}

struct Parser {
mut:
    idx int
	scanner   Scanner
}

struct Token {
	typ  TokenKind
	val  string
	line int
}

fn (mut s Scanner) tokenize(t_type TokenKind, val string) {
	s.tokens << Token{t_type, val, s.line}
}

fn (mut s Scanner) skip_whitespace() {
	for s.pos < s.text.len && s.text[s.pos].is_space() {
		s.pos++
	}
}

fn is_word(chr u8) bool {
	return chr.is_letter() || chr.is_digit() || chr == `_` || chr == `-`
}

fn (mut s Scanner) create_string(q u8) string {
	mut str := ''
	for s.pos < s.text.len && s.text[s.pos] != q {
		if s.text[s.pos] == `\\` && s.text[s.pos + 1] == q {
			str += s.text[s.pos..s.pos + 1]
			s.pos += 2
		} else {
			str += s.text[s.pos].ascii_str()
			s.pos++
		}
	}
	return str
}

fn (mut s Scanner) create_hex() string {
	mut text := ''
	for s.pos < s.text.len && s.text[s.pos].is_hex_digit() {
		text += s.text[s.pos].ascii_str()
		s.pos++
	}
	return text
}

fn (mut s Scanner) create_dec() string {
	mut text := ''
	for s.pos < s.text.len && (s.text[s.pos].is_digit() || s.text[s.pos] == `.`) {
		text += s.text[s.pos].ascii_str()
		s.pos++
	}
	return text
}

fn (mut s Scanner) create_ident() string {
	mut text := ''
	for s.pos < s.text.len && is_word(s.text[s.pos]) {
		text += s.text[s.pos].ascii_str()
		s.pos++
	}
	return text
}

fn (s Scanner) peek_char(c u8) bool {
	return s.pos - 1 < s.text.len && s.text[s.pos - 1] == c
}

fn (mut s Scanner) scan_all() {
	for s.pos < s.text.len {
		c := s.text[s.pos]
		if c.is_space() || c == `\\` {
			s.pos++
			if c == `\n` {
				s.line++
			}
			continue
		}
                if c.is_digit() {
                    num := s.create_dec()
                    s.tokenize(.dec, num)
                    if s.text[s.pos].is_letter() {
                        s.tokenize(.unit, s.create_ident())
                    } else if s.text[s.pos] == `%` {
                        s.tokenize(.unit, '%')
                        s.pos++
                    }
                    continue
                }
		if is_word(c) {
			name := s.create_ident()
			s.tokenize(.ident, name)
                        continue
		}
		if c in [`'`, `\"`] && !s.peek_char(`\\`) {
			s.pos++
			str := s.create_string(c)
			s.tokenize(.str, str)
			s.pos++
			continue
		}
		match c {
			`{` { s.tokenize(.lcbr, c.ascii_str()) }
			`}` { s.tokenize(.rcbr, c.ascii_str()) }
			`[` { s.tokenize(.labr, c.ascii_str()) }
			`]` { s.tokenize(.rabr, c.ascii_str()) }
			`:` { s.tokenize(.colon, c.ascii_str()) }
			`,` { s.tokenize(.comma, c.ascii_str()) }
                        `;` { s.tokenize(.semicolon, c.ascii_str()) }
                        `#` { s.pos++ s.tokenize(.hex, s.create_hex()) continue }
			else { s.tokenize(.unknown, c.ascii_str()) }
		}
		s.pos++
	}
	s.tokenize(.eof, 'eof')
}

const empty = Value(Empty{})

struct Empty {}

type Percentage = f32

enum Unit {
    raw
    percentage
    px
    em
}

struct Numerical {
mut:
    unit Unit
    value f64
}

type Value = Empty | string | gx.Color | Numerical | []Value


fn (p &Parser) peek(num int) Token {
    return p.scanner.tokens[p.idx + num]
}

fn (mut p Parser) next() Token {
    return p.scanner.tokens[p.idx++]
}

fn (mut p Parser) get_value() Value {
    tok := p.next()
    match tok.typ {
        .hex {
            val := u32(strconv.common_parse_uint(tok.val, 16, 32, true, false) or { return empty })
            return gx.hex(int(val << 8) | 0xFF)
        }
        .dec {
            mut val := Numerical{value: tok.val.f64()}
            next_tok := p.peek(0)
            if next_tok.typ == .unit {
                match next_tok.val  {
                    "em" {
                        val.unit = .em
                    }
                    "px" {
                        val.unit = .px
                    }
                    "%" {
                        val.unit = .percentage
                    }
                    else {
                        p.idx--
                    }
                }
                p.idx++
            } else {
                val.unit = .raw
            }
            return val
        }
        .ident, .str {
            return tok.val
        }
        else {
            return empty
        }
    }
}


fn (mut p Parser) parse() ?[]Rule {
	if p.scanner.text.len == 0 {
		return error('no content.')
	}

        mut rules := []Rule{}
        mut current_rule := Rule{}
        mut key := ""
        mut value := empty

        mut parsing_conds := true
        mut parsing_keys := false

	p.scanner.scan_all()
	tokens := p.scanner.tokens
	for p.idx < tokens.len {
		tok := tokens[p.idx]
                match tok.typ {
                    .lcbr {
                        parsing_conds = false
                        parsing_keys = true
                    }
                    .rcbr {
                        parsing_conds = true
                        parsing_keys = false
                        rules << current_rule
                        current_rule = Rule{}
                        key = ""
                    }
                    .ident {
                        if parsing_conds {
                            current_rule.conds << tok.val
                        } else if parsing_keys {
                            key = tok.val
                        }
                    }
                    .colon {
                        parsing_keys = false
                        p.idx++
                        value = p.get_value()
                        if p.peek(0).typ != .semicolon {
                            mut vals := [value]
                            for p.idx < tokens.len && tokens[p.idx].typ != .semicolon {
                                if tokens[p.idx].typ == .comma {
                                    p.idx++
                                    continue
                                }
                                vals << p.get_value()
                                p.idx++
                            }
                            value = vals
                            p.idx--
                        }
                        continue
                    }
                    .semicolon {
                        current_rule.fields[key] = value
                        key = ""
                        value = empty
                        parsing_keys = true
                    }
                    else {}
                }
                p.idx++
	}
        return rules
}
