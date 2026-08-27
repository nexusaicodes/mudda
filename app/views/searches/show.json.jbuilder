json.data @page.records, partial: "cards/card", as: :card
json.paging paging_for(@page)
