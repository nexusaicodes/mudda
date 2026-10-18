import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/timing_helpers"

// The header's search panel: a modal dialog with the search box at its top and the results
// below. Typing searches after a short pause; Esc, a click on the dimmed page, or following a
// result closes it.
export default class extends Controller {
  static targets = [ "dialog", "turboFrame", "searchInput", "form" ]

  initialize() {
    this.searchAsYouType = debounce(this.submit.bind(this), 250)
  }

  open() {
    this.dialogTarget.showModal()
    this.searchInputTarget.focus()
    this.searchInputTarget.select()
  }

  close() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  // Runs on the dialog's close, however it was closed.
  reset() {
    this.searchInputTarget.value = ""
    this.turboFrameTarget.removeAttribute("src")
    this.turboFrameTarget.innerHTML = ""
  }

  // A click on the dialog itself, not on anything inside it, is a click on the backdrop.
  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  submit() {
    if (this.searchInputTarget.value.trim()) {
      this.formTarget.requestSubmit()
    } else {
      this.turboFrameTarget.innerHTML = ""
    }
  }
}
