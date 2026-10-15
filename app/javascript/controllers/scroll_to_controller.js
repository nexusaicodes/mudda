import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "target" ]

  connect() {
    this.#scrollTargetIntoView()
  }

  #scrollTargetIntoView() {
    if(this.hasTargetTarget) {
      this.element.scrollTo({
        top: this.targetTarget.offsetTop - this.element.offsetHeight / 2 + this.targetTarget.offsetHeight / 2,
        left: this.#centredScrollLeft,
        behavior: "instant"
      })
    }
  }

  // In right-to-left, offsetLeft and scrollLeft both run negative from the start edge, so one
  // formula centres the target either way
  get #centredScrollLeft() {
    return this.targetTarget.offsetLeft - this.element.offsetWidth / 2 + this.targetTarget.offsetWidth / 2
  }
}
