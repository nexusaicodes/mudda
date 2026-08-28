import { Controller } from "@hotwired/stimulus"
import { debounce, nextFrame } from "helpers/timing_helpers"

// Keeps a form in the browser until it has been submitted successfully, so a reload or a
// closed tab does not lose what was typed. Every input target is stored under one key, by
// field name, and cleared together once the form goes through.
export default class extends Controller {
  static targets = ["input"]
  static values = { key: String }

  initialize() {
    this.save = debounce(this.save.bind(this), 300)
  }

  connect() {
    this.restore()
  }

  submit({ detail: { success } }) {
    if (success) {
      this.#clear()
    }
  }

  save() {
    const filled = this.inputTargets.filter(input => input.value)

    if (filled.length) {
      localStorage.setItem(this.keyValue, JSON.stringify(Object.fromEntries(filled.map(input => [input.name, input.value]))))
    } else {
      this.#clear()
    }
  }

  async restore() {
    await nextFrame()
    const saved = this.#saved()

    this.inputTargets.filter(input => saved[input.name]).forEach(input => this.#restoreInput(input, saved[input.name]))
  }

  // Private

  #saved() {
    const stored = localStorage.getItem(this.keyValue)

    if (stored) {
      return this.#parse(stored)
    } else {
      return {}
    }
  }

  #parse(stored) {
    try {
      const parsed = JSON.parse(stored)
      if (parsed && typeof parsed === "object") return parsed
    } catch {
      // Saved before forms were stored by field name, when there was only one field to store.
    }

    return this.#legacy(stored)
  }

  // A value from the single-field format is HTML, and the editor it belongs to needs it
  // wrapped the way it was written.
  #legacy(stored) {
    const input = this.inputTargets[0]
    return input ? { [input.name]: `<div>${stored}</div>` } : {}
  }

  #restoreInput(input, value) {
    input.value = value

    if (input.tagName === "LEXXY-EDITOR") {
      this.#triggerChangeEvent(input, value)
    }
  }

  #clear() {
    localStorage.removeItem(this.keyValue)
  }

  #triggerChangeEvent(input, newContent) {
    input.dispatchEvent(new CustomEvent("lexxy:change", {
      bubbles: true,
      detail: { previousContent: "", newContent }
    }))
  }
}
