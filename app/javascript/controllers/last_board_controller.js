import { Controller } from "@hotwired/stimulus"

// Remembers the board you last had open (per account) so the landing page can
// send you straight back to it. The read side lives in the `landing` controller.
export default class extends Controller {
  static values = { id: String, key: String }

  connect() {
    if (this.idValue && this.keyValue) {
      try {
        localStorage.setItem(this.keyValue, this.idValue)
      } catch (e) {}
    }
  }
}
