module Admin
  class PagesController < Admin::AdminController
    include PagesCore::Admin::NewsPageController

    before_action :find_categories
    before_action :find_page, only: %i[show edit update destroy
                                       move]

    require_authorization

    helper_method :page_json

    def index
      @pages = Page.admin_list(@locale)
    end

    def deleted
      @pages = Page.deleted.by_updated_at.in_locale(@locale)
    end

    def show
      redirect_to edit_admin_page_url(@locale, @page)
    end

    def new
      build_params = params[:page] ? page_params : nil
      @page = build_page(@locale, build_params)
      @page.parent = if params[:parent]
                       Page.find(params[:parent])
                     elsif @news_pages
                       @news_pages.first
                     end
    end

    def create
      @page = build_page(@locale, page_params, param_categories)
      if @page.valid?
        @page.save
        respond_with_page(@page) do
          redirect_to(edit_admin_page_url(@locale, @page))
        end
      else
        render action: :new
      end
    end

    def edit; end

    def update
      if @page.update(page_params)
        @page.categories = param_categories
        respond_with_page(@page) do
          flash[:notice] = "Your changes were saved"
          redirect_to edit_admin_page_url(@locale, @page)
        end
      else
        render action: :edit
      end
    end

    def move
      parent = params[:parent_id] ? Page.find(params[:parent_id]) : nil
      @page.update(parent: parent, position: params[:position])
      respond_with_page(@page) { redirect_to admin_pages_url(@locale) }
    end

    def destroy
      Page.find(params[:id]).flag_as_deleted!
      redirect_to admin_pages_url(@locale)
    end

    private

    def build_page(locale, attributes = nil, categories = nil)
      Page.new.localize(locale).tap do |page|
        page.author = default_author || current_user
        page.attributes = attributes if attributes
        page.categories = categories if categories
      end
    end

    def default_author
      User.find_by_email(PagesCore.config.default_author)
    end

    def page_attributes
      %i[template user_id status feed_enabled published_at redirect_to
         image_link news_page unique_name pinned parent_page_id serialized_tags
         meta_image_id starts_at ends_at all_day image_id path_segment
         meta_title meta_description open_graph_title open_graph_description]
    end

    def page_params
      params.require(:page).permit(
        PagesCore::Templates::TemplateConfiguration.all_blocks +
        page_attributes,
        page_images_attributes: %i[id position image_id primary _destroy],
        page_files_attributes: %i[id position attachment_id _destroy]
      )
    end

    def page_json(page)
      { id: page.id,
        param: page.to_param,
        parent_page_id: page.parent_page_id,
        locale: page.locale,
        status: page.status,
        news_page: page.news_page,
        name: page.name,
        published_at: page.published_at,
        pinned: page.pinned?,
        starts_at: page.starts_at,
        permissions: [(:edit if policy(page).edit?),
                      (:create if policy(page).edit?)].compact }
    end

    def param_categories
      return [] unless params[:category]
      params.permit(category: {})[:category]
            .to_hash
            .map { |id, _| Category.find(id) }
    end

    def find_page
      @page = Page.find(params[:id]).localize(@locale)
    end

    def find_categories
      @categories = Category.order("name")
    end

    def respond_with_page(page)
      respond_to do |format|
        format.html { yield }
        format.json { render json: page_json(page) }
      end
    end
  end
end
