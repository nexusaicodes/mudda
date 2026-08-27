Rails.application.routes.draw do
  root "landings#show"

  namespace :account do
    resource :settings, only: %i[ show update ]
  end

  resources :users, only: %i[ show edit update ] do
    scope module: :users do
      resource :avatar, only: %i[ show destroy ]
    end
  end

  resources :boards do
    scope module: :boards do
      resources :columns, only: %i[ index show update ] do
        scope module: :columns do
          resources :cards, only: :index
        end
      end
    end

    # Card numbers run per board, so a card is addressed by its board and its number.
    resources :cards, except: :new do
      scope module: :cards do
        resource :draft, only: :show
        resource :board, only: %i[ edit update ]
        resource :column, only: %i[ edit update ]
        resource :goldness, only: %i[ create destroy ]
        resource :image, only: :destroy
        resource :publish, only: :create
        resources :steps, except: :new
        resources :notes, except: :new

        namespace :drops do
          resource :column, only: :create
        end
      end
    end
  end

  # Cross-board lists: a filtered index and the card-mention autocomplete, neither of which
  # addresses a single card.
  resources :cards, only: :index
  namespace :cards do
    resources :previews, only: :index
  end

  resource :search, only: :show
  namespace :searches do
    resources :queries, only: :create
  end

  resources :filters, only: %i[ create destroy ] do
    scope module: :filters do
      collection do
        resource :settings_refresh, only: :create
      end
    end
  end

  resource :session, only: %i[ new destroy ] do
    scope module: :sessions do
      resource :password, only: :create
      resource :passkey, only: :create
    end
  end

  resource :landing, only: :show

  namespace :my do
    resource :passkey_challenge, only: :create
    resource :user, only: :show
    resources :passkeys, except: %i[ show new ]
    resource :timezone, only: :update
    resource :menu, only: :show
  end

  namespace :prompts do
    resources :cards, only: :index
  end

  resolve "Card" do |card, options|
    route_for :board_card, card.board, card, options
  end

  resolve "Note" do |note, options|
    options[:anchor] = ActionView::RecordIdentifier.dom_id(note)
    route_for :board_card, note.card.board, note.card, options
  end

  resolve "Event" do |event, options|
    polymorphic_url(event.eventable, options)
  end

  get "up", to: "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "pwa#service_worker"
end
