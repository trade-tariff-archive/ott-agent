import "@hotwired/turbo-rails"

function scrollToBottom() {
  if (!document.getElementById("messages-bottom")) return
  window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" })
}

function renderMermaid() {
  if (typeof mermaid === "undefined") return
  const diagrams = document.querySelectorAll(".mermaid:not([data-processed])")
  if (diagrams.length === 0) return
  mermaid.run({ nodes: diagrams })
}

document.addEventListener("turbo:load", () => { scrollToBottom(); renderMermaid() })
document.addEventListener("turbo:render", () => { scrollToBottom(); renderMermaid() })

if (typeof mermaid !== "undefined") {
  mermaid.initialize({ startOnLoad: false, theme: "default" })
}
