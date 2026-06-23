import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {
  static outlets = [ "navigable-list" ]

  connect() {
    this.morphCompletePromise = null
    this.morphCompleteResolver = null
  }

  handleKeydown(event) {
    if (this.#shouldIgnore(event) || this.#hasModifier(event)) return

    const handler = this.#keyHandlers[event.key.toLowerCase()]
    if (handler) {
      handler.call(this, event)
    }
  }

  // Called when turbo:morph completes - resolves our waiting promise
  handleMorphComplete() {
    if (this.morphCompleteResolver) {
      this.morphCompleteResolver()
      this.morphCompleteResolver = null
      this.morphCompletePromise = null
    }
  }

  // Private

  #shouldIgnore(event) {
    const target = event.target
    return target.tagName === "INPUT" ||
           target.tagName === "TEXTAREA" ||
           target.isContentEditable ||
           target.closest("input, textarea, [contenteditable], lexxy-editor")
  }

  #hasModifier(event) {
    return event.metaKey || event.ctrlKey || event.altKey || event.shiftKey
  }

  get #selectedCard() {
    // Find the navigable-list that currently has focus
    const focusedList = this.navigableListOutlets.find(list => list.hasFocus)
    if (!focusedList) return null

    const currentItem = focusedList.currentItem
    if (currentItem?.classList.contains("card") && !this.#hotkeysDisabled(focusedList)) {
      return { card: currentItem, controller: focusedList }
    }
    return null
  }

  async #assignToMe(event) {
    const selection = this.#selectedCard
    if (!selection) return

    const url = selection.card.dataset.cardAssignToSelfUrl
    if (url) {
      event.preventDefault()
      await post(url, { responseKind: "turbo-stream" })
    }
  }

  #hotkeysDisabled(navigableList) {
    return navigableList?.element.dataset.cardHotkeysDisabled === "true"
  }

  #keyHandlers = {
    m(event) { this.#assignToMe(event) }
  }
}
