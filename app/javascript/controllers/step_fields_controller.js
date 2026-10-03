import { Controller } from "@hotwired/stimulus"

// Owns the step rows on the new-card form. A new card's steps travel with it in
// steps_attributes, so until the form is submitted the rows are only fields.
export default class extends Controller {
  static targets = ["template", "list"]

  add() {
    this.#addRow()
    this.#focusLastStep()
  }

  // A restored form can hold more steps than the page was rendered with — see
  // local_save_controller. Adding them here rather than there keeps the markup in one place.
  expand({ detail: { count } }) {
    for (let i = 0; i < count; i++) this.#addRow()
  }

  // Private

  #addRow() {
    this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
  }

  #focusLastStep() {
    const inputs = this.listTarget.querySelectorAll("input[type='text']")
    inputs[inputs.length - 1]?.focus()
  }
}
