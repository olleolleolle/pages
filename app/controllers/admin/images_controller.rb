module Admin
  class ImagesController < Admin::AdminController
    before_action :find_image, only: %i[show edit update destroy]

    def index; end

    def show; end

    def new; end

    def edit; end

    def create
      @image = Image.create(image_params)
      if @image.valid?
        respond_to do |format|
          format.json do
            render json: @image, serializer: Admin::ImageSerializer
          end
        end
      end
    end

    def update
      @image.update(image_params)
      respond_to do |format|
        format.json { render action: :show }
      end
    end

    def destroy; end

    protected

    def localized_attributes
      %i[caption alternative]
    end

    def image_params
      params.require(:image).permit(
        :name, :description, :file,
        :crop_start_x, :crop_start_y, :crop_height, :crop_width, :locale,
        :crop_gravity_x, :crop_gravity_y,
        localized_attributes.each_with_object({}) do |a, h|
          h[a] = I18n.available_locales
        end
      )
    end

    def find_image
      @image = Image.find(params[:id])
    end
  end
end
