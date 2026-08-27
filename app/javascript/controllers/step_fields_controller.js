import { Controller } from "@hotwired/stimulus"

// Adds blank step rows to the new-card form. A new card's steps travel with it in
// steps_attributes, so until the form is submitted the rows are only fields.
export default class extends Controller {
  static targets = ["template", "list"]

  add() {
    this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
    this.#focusLastStep()
  }

  // Private

  #focusLastStep() {
    const inputs = this.listTarget.querySelectorAll("input[type='text']")
    inputs[inputs.length - 1]?.focus()
  }
}
