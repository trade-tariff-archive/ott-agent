import "@hotwired/turbo-rails"

function scrollToBottom() {
  const el = document.getElementById("messages-bottom")
  if (el) el.scrollIntoView({ behavior: "smooth" })
}

document.addEventListener("turbo:render", scrollToBottom)
document.addEventListener("DOMContentLoaded", scrollToBottom)
