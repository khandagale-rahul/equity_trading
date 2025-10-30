import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="loading"
export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    // Bind methods to preserve context
    this.boundShow = this.show.bind(this)
    this.boundHide = this.hide.bind(this)

    // Listen to Turbo events for navigation and form submissions
    document.addEventListener("turbo:submit-start", this.boundShow)
    document.addEventListener("turbo:submit-end", this.boundHide)
    document.addEventListener("turbo:before-fetch-request", this.boundShow)
    document.addEventListener("turbo:before-fetch-response", this.boundHide)
    document.addEventListener("turbo:frame-load", this.boundHide)
    document.addEventListener("turbo:load", this.boundHide)

    // Handle browser back/forward navigation and page restoration
    document.addEventListener("turbo:before-cache", this.boundHide)
    document.addEventListener("turbo:render", this.boundHide)
    document.addEventListener("turbo:before-render", this.boundHide)

    // Handle errors and restore interactivity
    document.addEventListener("turbo:fetch-request-error", this.boundHide)

    // Handle page visibility changes (tab switching, browser minimize)
    document.addEventListener("visibilitychange", this.boundHide)

    // Ensure overlay is hidden when page loads/restores from cache
    this.hide()
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener("turbo:submit-start", this.boundShow)
    document.removeEventListener("turbo:submit-end", this.boundHide)
    document.removeEventListener("turbo:before-fetch-request", this.boundShow)
    document.removeEventListener("turbo:before-fetch-response", this.boundHide)
    document.removeEventListener("turbo:frame-load", this.boundHide)
    document.removeEventListener("turbo:load", this.boundHide)
    document.removeEventListener("turbo:before-cache", this.boundHide)
    document.removeEventListener("turbo:render", this.boundHide)
    document.removeEventListener("turbo:before-render", this.boundHide)
    document.removeEventListener("turbo:fetch-request-error", this.boundHide)
    document.removeEventListener("visibilitychange", this.boundHide)
  }

  show() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("active")
    }
  }

  hide() {
    if (this.hasOverlayTarget) {
      // Remove active class immediately to prevent stuck overlay
      this.overlayTarget.classList.remove("active")
    }
  }
}
