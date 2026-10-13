import { Controller } from "@hotwired/stimulus"
import { differenceInDays, secondsToDate } from "helpers/date_helpers"

// The page's language with Western digits, e.g. "ar-u-nu-latn"
function locale() {
  return `${document.documentElement.lang || "en-US"}-u-nu-latn`
}

export default class extends Controller {
  static targets = [ "time", "date", "datetime", "shortdate", "ago", "indays", "daysago", "agoorweekday", "timeordate" ]
  static values = { refreshInterval: Number }
  static classes = [ "local-time-value"]

  #timer

  initialize() {
    this.timeFormatter = new Intl.DateTimeFormat(locale(), { timeStyle: "short" })
    this.dateFormatter = new Intl.DateTimeFormat(locale(), { dateStyle: "long" })
    this.shortdateFormatter = new Intl.DateTimeFormat(locale(), { month: "short", day: "numeric" })
    this.datetimeFormatter = new Intl.DateTimeFormat(locale(), { timeStyle: "short", dateStyle: "short" })
    this.agoFormatter = new AgoFormatter()
    this.daysagoFormatter = new DaysAgoFormatter()
    this.datewithweekdayFormatter = new Intl.DateTimeFormat(locale(), { weekday: "long", month: "long", day: "numeric" })
    this.indaysFormatter = new InDaysFormatter()
    this.agoorweekdayFormatter = new DaysAgoOrWeekdayFormatter()
    this.timeordateFormatter = new TimeOrDateFormatter()
  }

  connect() {
    this.#timer = setInterval(() => this.#refreshRelativeTimes(), 30_000)
  }

  disconnect() {
    clearInterval(this.#timer)
  }

  refreshAll() {
    this.constructor.targets.forEach(targetName => {
      this.targets.findAll(targetName).forEach(target => {
        this.#formatTime(this[`${targetName}Formatter`], target)
      })
    })
  }

  refreshTarget(event) {
    const target = event.target;
    const targetName = target.dataset.localTimeTarget
    this.#formatTime(this[`${targetName}Formatter`], target)
  }

  timeTargetConnected(target) {
    this.#formatTime(this.timeFormatter, target)
  }

  dateTargetConnected(target) {
    this.#formatTime(this.dateFormatter, target)
  }

  datetimeTargetConnected(target) {
    this.#formatTime(this.datetimeFormatter, target)
  }

  shortdateTargetConnected(target) {
    this.#formatTime(this.shortdateFormatter, target)
  }

  agoTargetConnected(target) {
    this.#formatTime(this.agoFormatter, target)
  }

  indaysTargetConnected(target) {
    this.#formatTime(this.indaysFormatter, target)
  }

  daysagoTargetConnected(target) {
    this.#formatTime(this.daysagoFormatter, target)
  }

  agoorweekdayTargetConnected(target) {
    this.#formatTime(this.agoorweekdayFormatter, target)
  }

  timeordateTargetConnected(target) {
    this.#formatTime(this.timeordateFormatter, target)
  }

  #refreshRelativeTimes() {
    this.agoTargets.forEach(target => {
      this.#formatTime(this.agoFormatter, target)
    })
  }

  #formatTime(formatter, target) {
    const dt = secondsToDate(parseInt(target.getAttribute("datetime")))
    target.innerHTML = formatter.format(dt)
    target.title = this.datetimeFormatter.format(dt)
  }
}

class AgoFormatter {
  format(dt) {
    const now = new Date()
    const seconds = (now - dt) / 1000
    const minutes = seconds / 60
    const hours = minutes / 60
    const days = hours / 24
    const weeks = days / 7
    const months = days / (365 / 12)
    const years = days / 365

    if (years >= 1) return this.#ago(years, "year")
    if (months >= 1) return this.#ago(months, "month")
    if (weeks >= 1) return this.#ago(weeks, "week")
    if (days >= 1) return this.#ago(days, "day")
    if (hours >= 1) return this.#ago(hours, "hour")
    if (minutes >= 1) return this.#ago(minutes, "minute")

    return capitalize(relativeFormatter("auto").format(0, "second"))
  }

  #ago(quantity, unit) {
    return relativeFormatter("always").format(-Math.floor(quantity), unit)
  }
}

class DaysAgoFormatter {
  format(date) {
    return styleableRelativeDays(-Math.max(0, differenceInDays(date, new Date())))
  }
}

class DaysAgoOrWeekdayFormatter {
  format(date) {
    const days = differenceInDays(date, new Date())

    if (days <= 1) {
      return new DaysAgoFormatter().format(date)
    } else {
      return new Intl.DateTimeFormat(locale(), { weekday: "long", month: "long", day: "numeric" }).format(date)
    }
  }
}

class InDaysFormatter {
  format(date) {
    return styleableRelativeDays(Math.max(0, differenceInDays(new Date(), date)))
  }
}

class TimeOrDateFormatter {
  format(date) {
    const days = differenceInDays(date, new Date())

    if (days >= 1) {
      return new Intl.DateTimeFormat(locale(), { month: "short", day: "numeric" }).format(date)
    } else {
      return new Intl.DateTimeFormat(locale(), { timeStyle: "short" }).format(date)
    }
  }
}

function styleableValue(value) {
  return `<span class="local-time-value">${value}</span>`
}

function relativeFormatter(numeric) {
  return new Intl.RelativeTimeFormat(locale(), { numeric })
}

// "today", "yesterday", "in 3 days", with the number (or the whole word) wrapped to be styled
function styleableRelativeDays(days) {
  const parts = relativeFormatter("auto").formatToParts(days, "day")

  if (parts.some(part => part.type === "integer")) {
    return parts.map(part => part.type === "literal" ? part.value : styleableValue(part.value)).join("")
  } else {
    return styleableValue(parts.map(part => part.value).join(""))
  }
}

function capitalize(text) {
  return text.charAt(0).toLocaleUpperCase(locale()) + text.slice(1)
}
