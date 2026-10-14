import { Controller } from "@hotwired/stimulus"

// Swaps a read-only display for its edit form in place. Cancel (or Esc) puts the display back
// with the field reset to its saved value.
export default class extends Controller {
  static targets = [ "display", "editor", "input" ]

  edit() {
    this.displayTarget.hidden = true
    this.editorTarget.hidden = false
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  cancel() {
    this.inputTarget.value = this.inputTarget.defaultValue
    this.editorTarget.hidden = true
    this.displayTarget.hidden = false
  }
}
