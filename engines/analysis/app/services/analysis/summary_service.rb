# The "front door" (public API) of the Analysis module for other modules.
# Report calls `Analysis::SummaryService.for_user(id)` instead of querying Analysis::Event directly,
# so it doesn't need to know Analysis' tables or that they live in a PostgreSQL database.
module Analysis
  class SummaryService
    def self.for_user(user_id)
      Event.where(user_id: user_id)
           .group(:name)
           .order(:name)
           .pluck(:name, Arel.sql("COUNT(*)"), Arel.sql("SUM(value)"))
           .map do |name, count, total|
             { name: name, count: count, total: total.to_i, average: (total.to_f / count).round(2) }
           end
    end
  end
end
