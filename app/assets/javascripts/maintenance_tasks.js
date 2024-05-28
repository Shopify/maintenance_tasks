//= require activestorage
//= require_self

function refresh() {
  const target = document.querySelector("[data-refresh]")
  if (!target || !target.dataset.refresh) return
  window.setTimeout(() => {
    document.body.style.cursor = "wait"
    fetch(document.location, { headers: { "X-Requested-With": "XMLHttpRequest" } }).then(
      async response => {
        const text = await response.text()
        const newDocument = new DOMParser().parseFromString(text, "text/html")
        const newTarget = newDocument.querySelector("[data-refresh]")
        if (newTarget) {
          target.replaceWith(newTarget)
        }
        document.body.style.cursor = ""
        refresh()
      },
      error => location.reload()
    )
  }, 3000)
}
document.addEventListener('DOMContentLoaded', refresh)
