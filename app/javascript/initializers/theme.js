// Turbo swaps only the body, so each page's theme rides on it and is copied to <html>
document.addEventListener("turbo:before-render", ({ detail: { newBody } }) => {
  const theme = newBody.dataset.htmlTheme

  if (theme) {
    document.documentElement.dataset.theme = theme
  } else {
    delete document.documentElement.dataset.theme
  }
})
