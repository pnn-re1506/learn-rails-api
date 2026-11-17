module Report
  # Detailed statistics of one website in one month, e.g.
  #   { site_id: 1, period: "2026-10", visits: 1200, page_views: 5400, bounce_rate: 41.5 }
  # `site_id` points to a Website::Site, which lives in ANOTHER database.
  class Detail < ApplicationRecord
    validates :user_id, presence: true
    validates :site_id, presence: true
    validates :period, format: { with: /\A\d{4}-(0[1-9]|1[0-2])\z/, message: "must look like 2026-10" },
                       uniqueness: { scope: %i[user_id site_id] }
    validates :visits, :page_views, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :bounce_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
    validate :site_must_exist

    # --- Approach 1: cross-database SQL JOIN (one query on the report connection) ---
    # Website::ReportJoin knows the database/table names; this model only asks for the SQL pieces.
    # Adds `site_ref_id`, `site_domain`, `site_name` to every returned record.
    scope :with_site, -> {
      joins(Website::ReportJoin.left_join_sql("#{table_name}.site_id"))
        .select("#{table_name}.*", Website::ReportJoin.select_sql)
    }
    scope :for_domain, ->(text) {
      where("#{Website::ReportJoin.domain_column} LIKE ?", "%#{sanitize_sql_like(text)}%")
    }
    scope :order_by_domain, -> { order(Arel.sql(Website::ReportJoin.domain_column), :id) }

    private

    # A foreign key cannot cross databases, so check through the Website module's front door.
    def site_must_exist
      return if site_id.blank? || Website::SiteService.exists?(site_id)

      errors.add(:site_id, "does not exist")
    end
  end
end
