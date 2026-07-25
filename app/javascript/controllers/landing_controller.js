import { Controller } from "@hotwired/stimulus"

// Sends you to the board you last had open (per account), falling back to the
// most recently active one. Runs on both full loads and Turbo navigations — the
// inline script in the landing view only covers the pre-paint full-load case.
export default class extends Controller {
  static values = { key: String, paths: Object, fallback: String }

  connect() {
    let last = null
    try { last = localStorage.getItem(this.keyValue) } catch (e) {}
    const target = (last && this.pathsValue[last]) || this.fallbackValue
    if (target) window.location.replace(target)
  }
}
