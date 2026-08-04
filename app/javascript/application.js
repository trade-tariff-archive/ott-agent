import "@hotwired/turbo-rails"

function scrollToBottom() {
  if (!document.getElementById("messages-bottom")) return
  window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" })
}

document.addEventListener("turbo:load", scrollToBottom)
document.addEventListener("turbo:render", scrollToBottom)
