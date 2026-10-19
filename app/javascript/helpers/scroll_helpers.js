export async function keepingScrollPosition(element, promise) {
  const originalPosition = element.getBoundingClientRect()

  await promise

  const currentPosition = element.getBoundingClientRect()

  const yDiff = currentPosition.top - originalPosition.top
  const xDiff = currentPosition.left - originalPosition.left

  findNearestScrollableYAncestor(element).scrollTop += yDiff
  findNearestScrollableXAncestor(element).scrollLeft += xDiff
}

// Private

function findNearestScrollableYAncestor(refElement) {
  return findNearest(refElement, (element) => {
    const largerThanVisibleArea = element.scrollHeight > element.clientHeight

    const overflowY = getComputedStyle(element).overflowY
    const scrollableStyle = overflowY === "scroll" || overflowY === "auto"

    return largerThanVisibleArea && scrollableStyle
  })
}

function findNearestScrollableXAncestor(refElement) {
  return findNearest(refElement, (element) => {
    const largerThanVisibleArea = element.scrollWidth > element.clientWidth

    const overflowX = getComputedStyle(element).overflowX
    const scrollableStyle = overflowX === "scroll" || overflowX === "auto"

    return largerThanVisibleArea && scrollableStyle
  })
}

function findNearest(element, fn) {
  while (element) {
    if (fn(element)) {
      return element
    } else {
      element = element.parentElement
    }
  }

  return document.documentElement
}
