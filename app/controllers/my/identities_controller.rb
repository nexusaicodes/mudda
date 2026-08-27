class My::IdentitiesController < ApplicationController
  def show
    @identity = Current.identity
  end
end
