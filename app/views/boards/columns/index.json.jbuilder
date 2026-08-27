json.data @columns, partial: "columns/column", as: :column
json.paging paging_for_all(@columns)
