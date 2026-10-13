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

  // Right-to-left scroll positions run from 0 at the start down to negative values
  get #centredScrollLeft() {
    const left = this.targetTarget.offsetLeft - this.element.offsetWidth / 2 + this.targetTarget.offsetWidth / 2

    if (getComputedStyle(this.element).direction === "rtl") {
      return left - (this.element.scrollWidth - this.element.clientWidth)
    } else {
      return left
    }
  }
}
