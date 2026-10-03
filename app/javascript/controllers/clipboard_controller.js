import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "source" ]

  select() {
    this.sourceTarget.select()
  }

  async copy() {
    this.select()
    await navigator.clipboard.writeText(this.sourceTarget.value)
  }
}
