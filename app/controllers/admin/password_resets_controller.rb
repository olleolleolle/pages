module Admin
  class PasswordResetsController < Admin::AdminController
    before_action :find_password_reset_token, only: %i[show update]
    before_action :check_for_expired_token, only: %i[show update]
    before_action :require_authentication, except: %i[create show update]

    layout "admin"

    def create
      @user = find_user_by_email(params[:username])
      if @user
        @password_reset_token = @user.password_reset_tokens.create
        deliver_password_reset(@user, @password_reset_token)
        flash[:notice] = "An email with further instructions has been sent"
      else
        flash[:notice] = "Couldn't find a user with that email address"
      end
      redirect_to login_admin_users_url
    end

    def show
      @user = @password_reset_token.user
    end

    def update
      @user = @password_reset_token.user
      if user_params[:password].present? && @user.update(user_params)
        @password_reset_token.destroy
        authenticate!(@user)
        flash[:notice] = "Your password has been changed"
        redirect_to login_admin_users_url
      else
        render action: :show
      end
    end

    private

    def deliver_password_reset(user, password_reset)
      AdminMailer.password_reset(
        user,
        admin_password_reset_with_token_url(
          password_reset, password_reset.token
        )
      ).deliver_now
    end

    def find_user_by_email(email)
      return unless email
      User.login_name(params[:username])
    end

    def user_params
      params.require(:user).permit(:password, :confirm_password)
    end

    def valid_token?(reset)
      reset && secure_compare(reset.token, params[:token])
    end

    def find_password_reset_token
      @password_reset_token = begin
                                PasswordResetToken.find(params[:id])
                              rescue ActiveRecord::RecordNotFound
                                nil
                              end

      return if valid_token?(@password_reset_token)

      flash[:notice] = "Invalid password reset request"
      redirect_to(login_admin_users_url) && return
    end

    def check_for_expired_token
      return unless @password_reset_token.expired?
      @password_reset_token.destroy
      flash[:notice] = "Your password reset link has expired"
      redirect_to(login_admin_users_url)
    end
  end
end
