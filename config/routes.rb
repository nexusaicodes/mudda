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
    # A board's columns are fixed and travel with the board itself, so what is left is the
    # browser's: one lane's cards, and the color picker.
    scope module: :boards do
      resources :columns, only: %i[ show update ]
    end

    # Card numbers run per board, so a card is addressed by its board and its number.
    resources :cards do
      scope module: :cards do
        resource :board, only: :edit
        resource :column, only: %i[ edit update ]
        resource :goldness, only: %i[ create destroy ]
        resources :steps, except: %i[ new index ]
        resources :notes, except: :new

        namespace :drops do
          resource :column, only: :create
        end
      end
    end
  end

  # The cross-board card list. Nesting it under a board narrows it; see CardsController.
  resources :cards, only: :index

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

  # Mudda as an OAuth 2.1 authorization server for MCP clients; see MCP.md → OAuth.
  use_doorkeeper do
    controllers authorizations: "oauth/authorizations"
    skip_controllers :applications, :authorized_applications, :token_info
  end

  namespace :oauth do
    resources :registrations, only: :create
  end

  # Discovery. A client may ask for either document at the root or with the resource's path
  # appended (/.well-known/oauth-protected-resource/mcp), and gets the same answer.
  get ".well-known/oauth-protected-resource(/*resource)", to: "oauth/protected_resources#show", format: false,
    as: :oauth_protected_resource
  get ".well-known/oauth-authorization-server(/*issuer)", to: "oauth/authorization_servers#show", format: false,
    as: :oauth_authorization_server

  namespace :my do
    resource :passkey_challenge, only: :create
    resource :user, only: :show
    resources :passkeys, except: %i[ show new ]
    resources :tokens, only: %i[ index create destroy ]
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
