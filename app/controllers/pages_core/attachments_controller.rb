module PagesCore
  class AttachmentsController < ::ApplicationController
    before_action :verify_signed_params
    before_action :find_attachment, only: %i[show download]

    caches_page :show

    def show
      send_attachment
    end

    def download
      send_attachment disposition: "attachment"
    end

    private

    def find_attachment
      @attachment = Attachment.find(params[:id])
    end

    def send_attachment(disposition: "inline")
      if stale?(etag: @attachment, last_modified: @attachment.updated_at)
        send_data(@attachment.data,
                  filename: @attachment.filename,
                  type: @attachment.content_type,
                  disposition: disposition)
      end
    end

    def verify_signed_params
      key = params[:id].to_i.to_s
      Attachment.verifier.verify(key, params[:digest])
    end
  end
end
