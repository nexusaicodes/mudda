json.data @page.records, partial: "cards/notes/note", as: :note
json.paging paging_for(@page)
