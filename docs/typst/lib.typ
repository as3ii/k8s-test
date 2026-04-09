// Inspired by:
// - https://imaginarytext.ca/posts/2025/img/article.typ
// - https://github.com/typst/templates/blob/main/charged-ieee/lib.typ

// Usefull for compatibility with pandoc metadata
#let to-string(var) = {
  if type(var) == str {
    var
  } else if type(var) != content {
    str(var)
  } else if var.has("text") {
    var.text
  } else if var.has("children") {
    var.children.map(to-string).join("")
  } else if var.has("body") {
    to-string(var.body)
  } else if var == [ ] {
    " "
  }
}

#let conf(
  title: [Title], // Title
  authors: (), // Each author have a name and an email
  paper-size: "a4",
  date: "",
  language: "en",
  pagenumbering: "1", // ignored, for pandoc compatibility
  cols: "1", // ignored, for pandoc compatibility
  body,
) = {
  import "@preview/note-me:0.5.0"
  set document(title: title, author: authors.map(a => to-string(a.name)))
  set heading(numbering: "1.")
  set page(
    paper: paper-size,
    header-ascent: 30% + 0pt,
    header: context {
      show smallcaps: set text(tracking: .14em)
      set text(12pt)
      // skip first page
      if (here().page()) > 1 {
        if calc.odd(here().page()) {
          // odd pages: title
          align(right, smallcaps(all: true)[#title])
        } else {
          // even pages: author
          //align(left, smallcaps(all: true)[#authors.first().name])
        }
      }
    },
    footer-descent: 30% + 0pt,
  )

  // Default text
  set text(size: 12pt, spacing: .4em, lang: language)

  // Code inline and block
  show raw: set text(ligatures: false, spacing: 100%)
  // Code inline
  show raw.where(block: false): box.with(
    fill: luma(240),
    inset: (x: 3pt, y: 0pt),
    outset: (y: 3pt),
    radius: 2pt,
  )
  // Code block
  show raw.where(block: true): set text(size: 1.0em)
  show raw.where(block: true): block.with(
    fill: luma(240),
    inset: 10pt,
    radius: 4pt,
  )

  // Links (do not highlight emails)
  show link: t => {
    if type(t.dest) == str and t.dest.starts-with("mailto") {
      t
    } else {
      set text(blue)
      underline(t)
    }
  }

  // Default paragraph
  //set par(first-line-indent: 0pt)

  // First page: cover
  place(center + top, float: true, scope: "parent", {
    set text(size: 16pt, weight: "medium")
    [Università di Bologna - Cesena]
  })

  align(horizon, {
    {
      // Title
      set align(center)
      set text(size: 36pt, weight: "bold")
      block(below: 1em, title)
    }
    {
      // Authors
      for i in range(calc.ceil(authors.len() / 3)) {
        let end = calc.min((i + 1) * 3, authors.len())
        let slice = authors.slice(i * 3, end)
        grid(
          columns: slice.len() * (1fr,),
          gutter: 1.5em,
          ..slice.map(author => align(center, {
            text(size: 16pt, author.name)
            if "email" in author [
              \
              #set text(size: .8em, weight: "light")
              #link("mailto:" + to-string(author.email))
            ]
          }))
        )
      }
    }
  })

  place(center + bottom, float: true, scope: "parent", {
    text(size: 16pt, weight: "medium", date)
  })

  pagebreak()

  // Page numbering starting from 1, roman numbers
  set page(footer: context {
    set text(10pt)
    if calc.odd(here().page()) {
      // odd pages
      align(right, counter(page).display("I"))
    } else {
      // even pages
      align(left, counter(page).display("I"))
    }
  })
  counter(page).update(1)

  // Second page: copyright
  align(bottom, {
    [
      #set par(first-line-indent: 0pt)
      #title
      #sym.copyright
      #to-string(date).find(regex("[0-9]{4}"))
      by #context { document.author.first() }
      is licensed under CC BY-SA 4.0. To view a copy of this license, visit
      https://creativecommons.org/licenses/by-sa/4.0/
      #align(center, image("cc-by-sa.png", alt: "cc-by-sa", width: 120pt))
    ]
  })

  pagebreak()

  // Third page: index
  outline()

  pagebreak()

  // Page numbering starting from 1, arabic numbers
  set page(footer: context {
    set text(10pt)
    if calc.odd(here().page()) {
      // odd pages
      align(right, counter(page).display("1"))
    } else {
      // even pages
      align(left, counter(page).display("1"))
    }
  })
  counter(page).update(1)

  body
}
