import { Controller } from "@hotwired/stimulus"

// Disables the publish buttons until the due date field holds a value, mirroring
// the server-side presence validation that blocks publishing a card without a due date.
export default class extends Controller {
  static targets = [ "input", "submit" ]

  connect() {
    this.refresh()
  }

  refresh() {
    const filled = this.hasInputTarget && this.inputTarget.value.trim().length > 0
    this.submitTargets.forEach(button => button.toggleAttribute("disabled", !filled))
  }
}
