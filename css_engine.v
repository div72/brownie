import gx

enum CheckTyp {
    tag_name
}

struct Rule {
mut:
    conds []string
    fields map[string]Value
}

pub fn (rule &Rule) applies_for(element Element) bool {
    // FIXME: This is utterly broken.
    for cond in rule.conds {
        if element.name == cond {
            return true
        }
    }
    return false
}

pub struct CSSEngine {
mut:
    rules []Rule
}

pub fn (mut engine CSSEngine) parse(text string) {
    mut parser := Parser{
        scanner: Scanner{
            pos: 0
            text: text
        }
    }
    engine.rules << parser.parse() or { eprintln(err) return }
}

pub fn (engine &CSSEngine) get_pixel_size(num Numerical, parent_size int) int {
    return match num.unit {
        .percentage {
            int(parent_size * num.value / 100)
        }
        .px, .raw {
            int(num.value)
        }
        .em {
            int(num.value * 12) // FIXME
        }
    }
}

pub fn (mut engine CSSEngine) apply(mut e Element) {
    for rule in engine.rules {
        if rule.applies_for(e) {
            for key, value in rule.fields {
                match key {
                    "background-color" {
                        match value {
                            gx.Color {
                                e.background = value
                            }
                            else {}
                        }
                    }
                    "width" {
                        // TODO: Use screen sizes.
                        val := value as Numerical
                        parent_size := if !isnil(e.parent) { e.parent.width } else { 800 }
                        e.width = engine.get_pixel_size(val, parent_size)
                    }
                    "height" {
                        val := value as Numerical
                        parent_size := if !isnil(e.parent) { e.parent.height } else { 600 }
                        e.height = engine.get_pixel_size(val, parent_size)
                    }
                    "margin" {
                        println(value)
                    }
                    else {}
                }
            }
        }
    }

    for child in e.children {
        mut child_ := &child[0]
        engine.apply(mut child_)
    }
}

pub fn (mut engine CSSEngine) calculate_layout(mut e Element) {
}
