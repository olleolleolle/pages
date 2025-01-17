module Admin
  class PageImageSerializer < ActiveModel::Serializer
    attributes :id, :page_id, :image_id, :position, :primary
    has_one :image, serializer: Admin::ImageSerializer
  end
end
