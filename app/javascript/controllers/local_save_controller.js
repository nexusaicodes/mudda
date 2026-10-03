import { Controller } from "@hotwired/stimulus"
import { debounce, nextFrame } from "helpers/timing_helpers"

// Keeps a form in the browser until it has been submitted successfully, so a reload or a
// closed tab does not lose what was typed. Every input target is stored under one key, by
// field name, and cleared together once the form goes through.
//
// Fields that repeat under one name — the new card's step rows — are stored as a list. The
// rows they need may not be on the page when the form comes back, so restoring dispatches
// local-save:expand and lets whoever owns those rows add them (see step_fields_controller).
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
    const saved = {}

    for (const [name, inputs] of this.#inputsByName()) {
      const values = this.#trailingBlanksRemoved(inputs.map(input => input.value))

      if (values.some(Boolean)) {
        saved[name] = inputs.length > 1 ? values : values[0]
      }
    }

    if (Object.keys(saved).length) {
      localStorage.setItem(this.keyValue, JSON.stringify(saved))
    } else {
      this.#clear()
    }
  }

  async restore() {
    await nextFrame()
    const saved = this.#saved()

    this.#requestMissingInputs(saved)
    this.#fill(saved)
  }

  // Private

  #inputsByName() {
    return this.inputTargets.reduce((groups, input) => {
      return groups.set(input.name, [ ...groups.get(input.name) || [], input ])
    }, new Map())
  }

  #trailingBlanksRemoved(values) {
    const trimmed = [ ...values ]
    while (trimmed.length && !trimmed.at(-1)) trimmed.pop()
    return trimmed
  }

  // Dispatched before filling, and handled synchronously, so the inputs it asks for are
  // targets by the time they are filled.
  #requestMissingInputs(saved) {
    for (const [name, value] of Object.entries(saved)) {
      const present = this.#inputsNamed(name).length
      const wanted = this.#listed(value).length

      if (present > 0 && wanted > present) {
        this.dispatch("expand", { detail: { name: name, count: wanted - present } })
      }
    }
  }

  #fill(saved) {
    for (const [name, value] of Object.entries(saved)) {
      const inputs = this.#inputsNamed(name)

      this.#listed(value).forEach((restored, index) => {
        if (inputs[index]) this.#restoreInput(inputs[index], restored)
      })
    }
  }

  // A single field is stored as a bare value and a repeating one as a list, so both are read
  // back the same way.
  #listed(value) {
    return Array.isArray(value) ? value : [ value ]
  }

  #inputsNamed(name) {
    return this.inputTargets.filter(input => input.name === name)
  }

  #saved() {
    const stored = localStorage.getItem(this.keyValue)

    if (stored) {
      return this.#parse(stored)
    } else {
      return {}
    }
  }

  // Anything that is not a field map is ignored rather than guessed at. Keys name a record
  // ("card-7"), and ids are not stable across a rebuild, so a value left by an older format
  // could otherwise be restored into a different record's form.
  #parse(stored) {
    try {
      const parsed = JSON.parse(stored)
      if (parsed && typeof parsed === "object") return parsed
    } catch {
      // Not a field map.
    }

    return {}
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
