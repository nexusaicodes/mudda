json.data @page.records, partial: "boards/board", as: :board
json.paging paging_for(@page)
