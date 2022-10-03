import gg
import gx
import net.html
import os
import strings

struct App {
mut:
    gg &gg.Context = unsafe { nil }
    title &char = unsafe { vcalloc(256) }

    root &Element = unsafe { nil }

    css_engine &CSSEngine = &CSSEngine{}
}

// Padding/Margin
struct Rect {
    top int
    bottom int
    left int
    right int
}

[heap]
struct Element {
mut:
    name string
    content string
    attrs map[string]string
    parent &Element = unsafe { nil }
    children []&Element

    text_cfg &gx.TextCfg = &gx.TextCfg{}
    background gx.Color // TODO: Drawable

    width int
    height int

    x int
    y int

    padding Rect
    margin Rect
}

fn (e &Element) str() string {
    mut sb := strings.new_builder(1024)
    sb.writeln("<${e.name}>")
    for child in e.children {
        sb.writeln(child.str())
    }
    sb.writeln("</${e.name}>")
    return sb.str()
}

fn (mut e Element) draw(mut app App) {
    app.gg.draw_rect_filled(e.x, e.y, e.width, e.height, e.background)
    if e.content.len > 0 {
        app.gg.draw_text(e.x, e.y, e.content, e.text_cfg)
    }
    for child in e.children {
        mut child_ := &child[0]
        child_.draw(mut app)
    }
}

fn (mut app App) apply_css(mut element Element) {
    app.css_engine.apply(mut element)
    for child in element.children {
        mut child_ := &child[0]
        app.apply_css(mut child_)
    }
}

fn (mut app App) handle_tag(tag &html.Tag) &Element {
    mut elem := &Element{}

    match tag.name {
        "!doctype", "html", "head" {
        }
        "body" {
        }
        "meta" {}
        "style" {
            if tag.attributes["type"] == "text/css" {
                app.css_engine.parse(tag.content)
            }
        }
        "title" {
            mut len := tag.content.len
            if len > 255 {
                len = 255
            }
            unsafe { vmemcpy(app.title, tag.content.str, len) }
        }
        else {}
    }

    elem.name = tag.name
    elem.content = tag.content
    for child in tag.children {
        mut elem_child := app.handle_tag(child)
        elem_child.parent = elem
        elem.children << elem_child
    }

    return elem
}

fn frame(mut app App) {
    app.gg.begin()
    app.root.draw(mut app)
    app.gg.end()
}

fn main() {
    mut app := &App{}
    app.css_engine.parse(os.read_file("base.css")?)
    mut root := html.parse_file("index.html").get_root()
    if root.name == "!doctype" {
        root = root.children[0]
    }
    app.root = app.handle_tag(root)
    app.apply_css(mut app.root)
    app.gg = gg.new_context(user_data: app window_title: unsafe { tos(app.title, 0) } frame_fn: frame)
    app.gg.run()
}
