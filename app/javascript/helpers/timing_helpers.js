export function debounce(fn, delay = 1000) {
  let timeoutId = null

  return (...args) => {
    clearTimeout(timeoutId)
    timeoutId = setTimeout(() => fn.apply(this, args), delay)
  }
}

export function nextEvent(element, eventName) {
  return new Promise(resolve => element.addEventListener(eventName, resolve, { once: true }))
}

export function nextFrame() {
  return new Promise(requestAnimationFrame)
}

export function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}
