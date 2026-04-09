#import "lib.typ": conf

#let lang = sys.inputs.at("language", default: "it").trim()

#show: conf.with(
  title: [Kubernetes deployment],
  authors: (
    (
      name: "Lorenzo Debertolis",
      email: "lorenzo.debertolis@studio.unibo.it",
    ),
  ),
  date: "30/03/2026",
  language: lang,
)

#include lang + "/main.typ"
