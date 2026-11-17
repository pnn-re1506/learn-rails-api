module Report
  # The FINAL report: Report's statistics + the website's domain/name, merged in two different ways.
  # Both endpoints return the same JSON and accept the same params, so the results can be compared:
  #   ?domain=shop   keep only sites whose domain contains "shop"
  #   ?sort=domain   order by domain (default: visits, highest first)
  class ReportsController < ApplicationController
    # GET /report/reports/via_join
    # Approach 1: ONE SQL query joining report_details with website_sites across databases.
    # Filtering and sorting by a website column happen inside MySQL.
    def via_join
      details = user_details.with_site
      details = details.for_domain(params[:domain]) if params[:domain].present?
      details = params[:sort] == "domain" ? details.order_by_domain : details.order(visits: :desc, id: :asc)

      rows = details.map do |detail|
        site = { id: detail.site_ref_id, domain: detail.site_domain, name: detail.site_name } if detail.site_ref_id
        row(detail, site)
      end

      render json: build_report("join", rows)
    end

    # GET /report/reports/via_service
    # Approach 2: two queries. Ask Website (through its service) for the sites, then merge in Ruby.
    # Filtering by domain needs the site ids first; sorting by domain has to be done in Ruby.
    def via_service
      details = user_details
      details = details.where(site_id: Website::SiteService.ids_by_domain(params[:domain])) if params[:domain].present?
      details = details.order(visits: :desc, id: :asc).to_a

      sites = Website::SiteService.find_many(details.map(&:site_id).uniq)
      rows  = details.map { |detail| row(detail, sites[detail.site_id]) }
      rows  = rows.sort_by { |r| [ r.dig(:site, :domain).to_s, r[:id] ] } if params[:sort] == "domain"

      render json: build_report("service", rows)
    end

    private

    def user_details
      Detail.where(user_id: current_user.id)
    end

    # `site` is nil when the site no longer exists (no foreign key between databases).
    def row(detail, site)
      {
        id: detail.id,
        period: detail.period,
        visits: detail.visits,
        page_views: detail.page_views,
        bounce_rate: detail.bounce_rate.to_f,
        site: site
      }
    end

    def build_report(via, rows)
      {
        via: via,
        count: rows.size,
        total_visits: rows.sum { |r| r[:visits] },
        total_page_views: rows.sum { |r| r[:page_views] },
        rows: rows
      }
    end
  end
end
