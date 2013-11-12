class ProblemsController < ApplicationController
  before_filter :find_app, :except => [:index, :all, :destroy_several, :resolve_several, :unresolve_several, :merge_several, :unmerge_several]
  before_filter :find_problem, :except => [:index, :all, :destroy_several, :resolve_several, :unresolve_several, :merge_several, :unmerge_several]
  before_filter :find_selected_problems, :only => [:destroy_several, :resolve_several, :unresolve_several, :merge_several, :unmerge_several]
  before_filter :set_sorting_params, :only => [:index, :all]
  before_filter :set_tracker_params, :only => [:create_issue]

  def index
    app_scope = current_user.admin? ? App.all : current_user.apps

    @problems = Problem.for_apps(app_scope).in_env(params[:environment]).unresolved.ordered_by(@sort, @order)
    @selected_problems = params[:problems] || []
    respond_to do |format|
      format.html do
        @problems = @problems.page(params[:page]).per(current_user.per_page)
      end
      format.atom
    end
  end

  def all
    app_scope = current_user.admin? ? App.all : current_user.apps
    @problems = Problem.for_apps(app_scope).ordered_by(@sort, @order).page(params[:page]).per(current_user.per_page)
    @selected_problems = params[:problems] || []
  end

  def show
    @notices  = @problem.notices.reverse_ordered.page(params[:notice]).per(1)
    @notice   = @notices.first
    @comment = Comment.new
    if request.headers['X-PJAX']
      params["_pjax"] = nil
      render :layout => false
    end
  end

  def create_issue
    issue_creation = IssueCreation.new(@problem, current_user, params[:tracker])

    unless issue_creation.execute
      flash[:error] = issue_creation.errors[:base].first
    end

    redirect_to app_problem_path(@app, @problem)
  end

  def unlink_issue
    @problem.update_attribute :issue_link, nil
    redirect_to app_problem_path(@app, @problem)
  end

  def resolve
    @problem.resolve!
    flash[:success] = 'Great news everyone! The err has been resolved.'
    redirect_to :back
  rescue ActionController::RedirectBackError
    redirect_to app_path(@app)
  end

  def resolve_several
    @selected_problems.each(&:resolve!)
    flash[:success] = "Great news everyone! #{I18n.t(:n_errs_have, :count => @selected_problems.count)} been resolved."
    redirect_to :back
  end

  def unresolve_several
    @selected_problems.each(&:unresolve!)
    flash[:success] = "#{I18n.t(:n_errs_have, :count => @selected_problems.count)} been unresolved."
    redirect_to :back
  end

  def merge_several
    if @selected_problems.length < 2
      flash[:notice] = "You must select at least two errors to merge"
    else
      @merged_problem = Problem.merge!(@selected_problems)
      flash[:notice] = "#{@selected_problems.count} errors have been merged."
    end
    redirect_to :back
  end

  def unmerge_several
    all = @selected_problems.map(&:unmerge!).flatten
    flash[:success] = "#{I18n.t(:n_errs_have, :count => all.length)} been unmerged."
    redirect_to :back
  end

  def destroy_several
    nb_problem_destroy = ProblemDestroy.execute(@selected_problems)
    flash[:notice] = "#{I18n.t(:n_errs_have, :count => nb_problem_destroy)} been deleted."
    redirect_to :back
  end

  protected
    def find_app
      app_id = params[:app_id]
      if !app_id.match(/^[0-9]+$/)
        app_id = App.find_by_remote_id(app_id).id
      end
      @app = current_user.admin? ? App.find(app_id) : current_user.apps.find(app_id)
    end

    def find_problem
      if !params[:id].match(/^[0-9]+$/)
        @problem = @app.problems.find_by_remote_id(params[:id])
        redirect_to app_problem_path @app, @problem
      else
        @problem = @app.problems.find(params[:id])
      end
    end

    def set_tracker_params
      IssueTracker.default_url_options[:host] = request.host
      IssueTracker.default_url_options[:port] = request.port
      IssueTracker.default_url_options[:protocol] = request.scheme
    end

    def find_selected_problems
      err_ids = (params[:problems] || []).compact
      if err_ids.empty?
        flash[:notice] = "You have not selected any errors"
        redirect_to :back
      else
        @selected_problems = Array(Problem.find(err_ids))
      end
    end

    def set_sorting_params
      @sort = params[:sort]
      @sort = "last_notice_at" unless %w{app message last_notice_at last_deploy_at count}.member?(@sort)
      @order = params[:order] || "desc"
    end
end

