module PaginationHelper
  # The paging block every index JSON response carries alongside its data. Page size is
  # geared — 15, then 30, then 50, then 100 a page (GearedPagination::Ratios) — so there is
  # no single per_page worth reporting.
  def paging_for(page)
    {
      total: page.recordset.records_count,
      page: page.number,
      pages: page.recordset.page_count,
      next: (next_page_url(page) if page.before_last?)
    }
  end

  # The same block for an index that returns everything it has, so a client reads one shape
  # across every index rather than checking which ones paginate.
  def paging_for_all(records)
    { total: records.size, page: 1, pages: 1, next: nil }
  end

  def pagination_frame_tag(namespace, page, data: {}, **attributes, &)
    turbo_frame_tag pagination_frame_id_for(namespace, page.number), data: { timeline_target: "frame", **data }, role: "presentation", **attributes, &
  end

  def link_to_next_page(namespace, page, activate_when_observed: false, label: default_pagination_label(activate_when_observed), data: {}, **attributes)
    if page.before_last? && !params[:previous]
      attributes[:class] = class_names(attributes[:class], "btn txt-small center-block center": !activate_when_observed)
      pagination_link(namespace, page.number + 1, label: label, activate_when_observed: activate_when_observed, data: data, **attributes)
    end
  end

  def pagination_link(namespace, page_number, activate_when_observed: false, label: default_pagination_label(activate_when_observed), url_params: {}, data: {}, **attributes)
    link_to label, url_for(params.permit!.to_h.merge(page: page_number, **url_params)),
      "aria-label": "Load page #{page_number}",
      id: "#{namespace}-pagination-link-#{page_number}",
      class: class_names(attributes.delete(:class), "pagination-link", { "pagination-link--active-when-observed" => activate_when_observed }),
      data: {
        frame: pagination_frame_id_for(namespace, page_number),
        pagination_target: "paginationLink",
        action: ("click->pagination#loadPage:prevent" unless activate_when_observed),
        **data
      },
      **attributes
  end

  def pagination_frame_id_for(namespace, page_number)
    "#{namespace}-pagination-contents-#{page_number}"
  end

  def with_automatic_pagination(name, page, **properties)
    pagination_list name, paginate_on_scroll: true, **properties do
      concat(pagination_frame_tag(name, page) do
        yield
        concat link_to_next_page(name, page, activate_when_observed: true)
      end)
    end
  end

  private
    # Built from the request's own URL rather than from its params: url_for reads :host,
    # :protocol and :port as options, so a caller could otherwise put `?host=` in the query
    # and be handed a `next` pointing at their own server — which a client following it would
    # send its bearer token to. This is how geared_pagination builds the Link header.
    def next_page_url(page)
      Addressable::URI.parse(request.url).tap do |uri|
        uri.query_values = (uri.query_values || {}).merge("page" => page.next_param.to_s)
      end.to_s
    end

    def pagination_list(name, tag_element: :div, paginate_on_scroll: false, **properties, &block)
      classes = properties.delete(:class)
      properties[:id] ||= "#{name}-pagination-list"
      tag.public_send tag_element,
        class: token_list(name, "display-contents", classes),
        data: { controller: "pagination", pagination_paginate_on_intersection_value: paginate_on_scroll },
        **properties,
        &block
    end

    def default_pagination_label(activate_when_observed)
      "Load more…"
    end
end
