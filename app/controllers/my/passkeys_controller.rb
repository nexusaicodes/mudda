class My::PasskeysController < ApplicationController
  include ActionPack::Passkey::Request

  skip_passkey_enrollment
  before_action :set_passkey, only: %i[ edit update destroy ]

  def index
    @passkeys = Current.identity.passkeys.order(name: :asc, created_at: :desc)
    @registration_options = passkey_registration_options(holder: Current.identity)
  end

  def create
    first_passkey = Current.identity.passkeys.none?
    passkey = Current.identity.passkeys.register(passkey_registration_params)

    if first_passkey
      # Onboarding complete: the day-0 password gives way to passkey sign-in from here on.
      flash[:welcome_letter] = true
      redirect_to landing_path
    else
      redirect_to edit_my_passkey_path(passkey, created: true)
    end
  rescue ActionPack::WebAuthn::Error, ActiveRecord::RecordNotUnique
    redirect_to my_passkeys_path, alert: "That passkey couldn't be registered. Try again."
  end

  def edit
  end

  def update
    @passkey.update!(params.expect(passkey: [ :name ]))
    redirect_to my_passkeys_path
  end

  def destroy
    if Current.identity.passkeys.many?
      @passkey.destroy!
      redirect_to my_passkeys_path
    else
      redirect_to my_passkeys_path, alert: "You can't remove your only passkey. Run bin/rails auth:reset to start over."
    end
  end

  private
    def set_passkey
      @passkey = Current.identity.passkeys.find(params[:id])
    end
end
