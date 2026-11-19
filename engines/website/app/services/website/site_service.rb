# "Front door" #1 of the Website module for other modules (approach 2: call a method).
# Report asks for sites by id and merges them in Ruby. It never touches Website::Site directly,
# so it doesn't need to know the table name or which database it lives in.
module Website
  class SiteService
    # Returns { site_id => { id:, domain:, name: } } for the given ids (one query, no N+1).
    def self.find_many(ids)
      Site.where(id: ids).index_by(&:id).transform_values { |site| present(site) }
    end

    # Ids of the sites whose domain contains `text` (used by Report to filter by domain).
    def self.ids_by_domain(text)
      Site.where("domain LIKE ?", "%#{Site.sanitize_sql_like(text)}%").pluck(:id)
    end

    def self.exists?(id)
      Site.exists?(id)
    end

    # May `user` (a System::User) add report statistics for this site? (owner, editor or admin)
    # The rule itself stays in Website::SitePolicy: Report never needs to know about site roles.
    def self.can_write_reports?(user, site_id)
      site = Site.find_by(id: site_id)
      site.present? && SitePolicy.new(user, site).write_reports?
    end

    def self.present(site)
      { id: site.id, domain: site.domain, name: site.name }
    end
  end
end
