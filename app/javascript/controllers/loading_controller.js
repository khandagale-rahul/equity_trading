import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="loading"
export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    this.show = this.show.bind(this)
    this.hide = this.hide.bind(this)

    // Show immediately when user interacts
    document.addEventListener("click", this.show, { capture: true })
    document.addEventListener("submit", this.show, { capture: true })

    // Show loader on any navigation intent
    document.addEventListener("turbo:before-visit", this.show)
    document.addEventListener("turbo:submit-start", this.show)
    document.addEventListener("turbo:before-fetch-request", this.show)

    // Hide only when a real fetch responds OR Turbo finishes render
    document.addEventListener("turbo:fetch-response", this.hide)
    document.addEventListener("turbo:load", this.hide)
    document.addEventListener("turbo:frame-render", this.hide)
    document.addEventListener("turbo:before-cache", this.hide)

    // Browser back/forward button
    window.addEventListener("popstate", this.show)
  }

  disconnect() {
    document.removeEventListener("click", this.show, { capture: true })
    document.removeEventListener("submit", this.show, { capture: true })

    document.removeEventListener("turbo:before-visit", this.show)
    document.removeEventListener("turbo:submit-start", this.show)
    document.removeEventListener("turbo:before-fetch-request", this.show)

    document.removeEventListener("turbo:fetch-response", this.hide)
    document.removeEventListener("turbo:load", this.hide)
    document.removeEventListener("turbo:frame-render", this.hide)
    document.removeEventListener("turbo:before-cache", this.hide)

    window.removeEventListener("popstate", this.show)
  }

  show(event) {
    if (!this.hasOverlayTarget) return

    this.overlayTarget.classList.remove("hidden")
    this.overlayTarget.offsetHeight
    document.body.style.pointerEvents = "none"
  }

  hide(event) {
    if (!this.hasOverlayTarget) return

    // super fast requests avoid flicker
    setTimeout(() => {
      this.overlayTarget.classList.add("hidden")
      document.body.style.pointerEvents = "auto"
    }, 40)
  }
}
