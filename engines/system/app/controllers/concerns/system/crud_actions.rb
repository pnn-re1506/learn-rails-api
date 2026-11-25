# Generic CRUD for a JSON API: index, show, create, update, destroy.
#
# A controller gets all five actions by declaring two things:
#
#   class ProductsController < ApplicationController
#     private
#     def model_class    = Product
#     def record_params  = params.expect(product: %i[name price])
#   end
#
# Which actions are exposed is decided by routes (`resources :products, only: [...]`).
#
# Customize by overriding a HOOK (small change) or a whole action (big change, `super` is allowed):
#
#   scope                         records this controller may touch (default: model_class.all)
#   collection                    what `index` lists (default: scope ordered by id)
#   find_record                   how one record is found (default: scope.find(params[:id]))
#   build_record                  how `create` builds a record (default: scope.new(record_params))
#   authorize_record!(action, r)  permission check, action is :create/:update/:destroy (default: allow)
#   serialize(record)             JSON for one record (default: the record itself)
#
# Query params of `index` (all optional), switched on by these hooks:
#
#   filter_fields   [:site_id, :period]   ?site_id=1&period=2026-10   exact match on each field
#   search_fields   [:domain, :name]      ?q=shop                      "contains" on ANY of these fields
#   sortable_fields [:id, :domain]        ?sort=domain&direction=desc  order (direction: asc|desc, default asc)
#
# A field not listed is ignored, so a client can never filter or sort on a column you did not allow.
module System
  module CrudActions
    def index
      render json: sort_records(search_records(filter_records(collection))).map { |record| serialize(record) }
    end

    def show
      render json: serialize(find_record)
    end

    # Order of checks: 422 (invalid data) first, then 403 (not allowed), then save.
    def create
      record = build_record
      return render_validation_errors(record) unless record.valid?

      authorize_record!(:create, record)
      record.save!
      render json: serialize(record), status: :created
    end

    def update
      record = find_record
      authorize_record!(:update, record)

      if record.update(record_params)
        render json: serialize(record)
      else
        render_validation_errors(record)
      end
    end

    def destroy
      record = find_record
      authorize_record!(:destroy, record)

      if record.destroy
        head :no_content
      else
        render_validation_errors(record)
      end
    end

    private

    def model_class
      raise NotImplementedError, "#{self.class} must define #model_class"
    end

    def record_params
      raise NotImplementedError, "#{self.class} must define #record_params"
    end

    def scope
      model_class.all
    end

    def collection
      scope.order(:id)
    end

    def find_record
      scope.find(params[:id])
    end

    def build_record
      scope.new(record_params)
    end

    def filter_fields
      []
    end

    def search_fields
      []
    end

    def sortable_fields
      (filter_fields + search_fields + [ :id ]).uniq
    end

    def filter_records(relation)
      filter_fields.reduce(relation) do |records, field|
        value = params[field]
        # Only plain strings: ignores ?field[a]=b style input.
        value.is_a?(String) && value.present? ? records.where(field => value) : records
      end
    end

    def search_records(relation)
      return relation if search_fields.empty? || params[:q].blank? || !params[:q].is_a?(String)

      pattern = "%#{model_class.sanitize_sql_like(params[:q])}%"
      table   = model_class.arel_table
      relation.where(search_fields.map { |field| table[field].matches(pattern) }.reduce(:or))
    end

    def sort_records(relation)
      field = params[:sort].to_s.to_sym
      return relation unless sortable_fields.include?(field)

      direction = params[:direction].to_s.downcase == "desc" ? :desc : :asc
      ordering = { field => direction }
      ordering[:id] ||= :asc   # tie-breaker, so the order is stable
      relation.reorder(ordering)
    end

    # Allowed by default. Override with: authorize!(MyPolicy.new(current_user, record), :"#{action}?")
    def authorize_record!(_action, _record)
    end

    def serialize(record)
      record
    end
  end
end
