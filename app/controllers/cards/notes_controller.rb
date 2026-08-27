class Cards::NotesController < ApplicationController
  wrap_parameters :note, include: %i[ body created_at ]
  include CardScoped, StrictQueryParams

  before_action :set_note, only: %i[ show edit update destroy ]
  before_action :ensure_creatorship, only: %i[ edit update destroy ]
  before_action :ensure_card_is_notable, only: :create

  def index
    set_page_and_extract_portion_from @card.notes.chronologically
  end

  def create
    @note = @card.notes.create!(note_params)

    respond_to do |format|
      format.turbo_stream
      format.json { render :show, status: :created, location: board_card_note_path(@card.board, @card, @note, format: :json) }
    end
  end

  def show
  end

  def edit
  end

  def update
    @note.update! note_params

    respond_to do |format|
      format.turbo_stream
      format.json { render :show }
    end
  end

  def destroy
    @note.destroy

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private
    def set_note
      @note = @card.notes.find(params[:id])
    end

    def ensure_creatorship
      head :forbidden if Current.user != @note.creator
    end

    def ensure_card_is_notable
      head :forbidden unless @card.notable?
    end

    def note_params
      params.expect(note: [ :body, :created_at ])
    end
end
