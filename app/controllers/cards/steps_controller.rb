class Cards::StepsController < ApplicationController
  wrap_parameters :step, include: %i[ content completed ]

  include CardScoped, BrowserOnly, StrictQueryParams

  before_action :set_step, only: %i[ show edit update destroy ]

  # The browser edits steps one at a time. Everywhere else they are part of the card, written
  # through its steps_attributes (see Card::Multistep) and read from its own representation.
  def create
    @step = @card.steps.create!(step_params)
  end

  def show
  end

  def edit
  end

  def update
    @step.update!(step_params)
  end

  def destroy
    @step.destroy!
  end

  private
    def set_step
      @step = @card.steps.find(params[:id])
    end

    def step_params
      params.expect(step: [ :content, :completed ])
    end
end
