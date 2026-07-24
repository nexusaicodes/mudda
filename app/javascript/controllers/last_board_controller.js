import { Controller } from "@hotwired/stimulus"

// Remembers the board you last had open (per account) so the landing page can
// send you straight back to it. The read side lives in the `landing` controller.
export default class extends Controller {
  static values = { id: String, account: String }

  connect() {
    if (this.idValue && this.accountValue) {
      try {
        localStorage.setItem(`mudda:last-board:${this.accountValue}`, this.idValue)
      } catch (e) {}
    }
  }
}
