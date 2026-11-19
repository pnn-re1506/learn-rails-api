module Website
  # Members of one site: /website/sites/:site_id/members
  # A member is identified in the URL by their USER id: DELETE /website/sites/1/members/5
  class MembersController < ApplicationController
    before_action :set_site

    # GET /website/sites/:site_id/members   (any member of the site)
    def index
      authorize!(policy, :show?)

      members = @site.members.order(:id).to_a
      emails  = System::UserService.emails_for(members.map(&:user_id))
      render json: members.map { |member| member_json(member, emails[member.user_id]) }
    end

    # POST /website/sites/:site_id/members   body: { "member": { "email": "bob@example.com", "role": "editor" } }
    # (owner or admin)
    def create
      authorize!(policy, :manage_members?)

      attrs   = params.expect(member: %i[email role])
      user_id = System::UserService.id_by_email(attrs[:email])
      return render json: { errors: { email: [ "has no account" ] } }, status: :unprocessable_content unless user_id

      member = @site.members.build(user_id: user_id, role: attrs[:role])
      if member.save
        render json: member_json(member), status: :created
      else
        render_validation_errors(member)
      end
    end

    # PATCH /website/sites/:site_id/members/:user_id   body: { "member": { "role": "viewer" } }   (owner or admin)
    def update
      authorize!(policy, :manage_members?)

      member = @site.members.find_by!(user_id: params[:user_id])
      if member.update(params.expect(member: [ :role ]))
        render json: member_json(member)
      else
        render_validation_errors(member)
      end
    end

    # DELETE /website/sites/:site_id/members/:user_id   (owner or admin)
    def destroy
      authorize!(policy, :manage_members?)

      member = @site.members.find_by!(user_id: params[:user_id])
      if member.destroy
        head :no_content
      else
        render_validation_errors(member)   # e.g. the last owner
      end
    end

    private

    # Same rule as SitesController: a site you cannot see is a 404.
    def set_site
      @site = find_accessible_site(params[:site_id])
    end

    def policy
      @policy ||= SitePolicy.new(current_user, @site)
    end

    def member_json(member, email = nil)
      { user_id: member.user_id, email: email, role: member.role }.compact
    end
  end
end
