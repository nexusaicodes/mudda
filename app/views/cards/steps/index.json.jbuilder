json.data @card.steps, partial: "cards/steps/step", as: :step
json.paging paging_for_all(@card.steps)
