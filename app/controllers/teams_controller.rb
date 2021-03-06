class TeamsController < ApplicationController
  before_action :require_login
  before_action :set_team, only: [:show, :edit, :update, :invitations, :leave]

  # GET /teams
  def index
    @teams = current_user.teams
    @pending_team_invitations = TeamInvitation.where(email: current_user.email, accepted: false)
    add_breadcrumb Team.model_name.human(count: 2)
  end

  # GET /teams/1
  def show
    @subscriptions = @team.subscriptions.page(params[:page])
    @is_admin = current_user.is_team_admin?(@team)
    add_breadcrumb @team.title, @team
  end

  # GET /teams/new
  def new
    @team = Team.new
    add_breadcrumb Team.model_name.human(count: 2), teams_path
    add_breadcrumb t '.new_team'
  end

  # GET /teams/1/edit
  def edit
    add_breadcrumb Team.model_name.human(count: 2), teams_path
    add_breadcrumb t '.edit_team'
  end

  # POST /teams
  def create
    @team = Team.create_and_subscribe_admin(team_params, current_user)
    respond_with @team, location: -> { teams_url }
  end

  # PATCH/PUT /teams/1
  def update
    @team.update(update_team_params)
    respond_with @team, location: -> { teams_url }
  end

  def invitations
    @team_invitation = TeamInvitation.new(team: @team)

    add_breadcrumb Team.model_name.human(count: 2), teams_path
    add_breadcrumb @team.title
    add_breadcrumb TeamInvitation.model_name.human
  end

  def leave
    ActiveRecord::Base.transaction do
      Subscription.find_by(subscriptable: @team, user: current_user).destroy
      TeamInvitation.find_by(team: @team, email: current_user.email).destroy
    end

    redirect_to teams_path
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_team
    @team = Team.accessible_for(current_user).friendly.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def team_params
    params.require(:team).permit(:title, :public, {join_requirement_ids: []})
  end

  def update_team_params
    params.require(:team).permit(:title, :public)
  end
end
