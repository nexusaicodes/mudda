Rails.application.routes.draw do
  root "events#index"

  namespace :account do
    resource :cancellation, only: [ :create ]
    resource :settings
  end

  resources :users, only: %i[ show edit update ] do
    scope module: :users do
      resource :avatar
      resource :events

      resources :email_addresses, param: :token do
        resource :confirmation, module: :email_addresses
      end
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

    resources :cards, only: :create
  end

  namespace :columns do
    resources :cards do
      scope module: :cards do
        namespace :drops do
          resource :column
        end
      end
    end
  end

  namespace :cards do
    resources :previews
  end

  resources :cards do
    scope module: :cards do
      resource :draft, only: :show
      resource :board
      resource :column
      resource :goldness
      resource :image
      resource :publish
      resources :steps

      resources :notes
    end
  end

  resource :search
  namespace :searches do
    resources :queries
  end

  resources :filters do
    scope module: :filters do
      collection do
        resource :settings_refresh, only: :create
      end
    end
  end

  resources :activities, only: :index
  resources :events, only: :index
  namespace :events do
    resources :days
    namespace :day_timeline do
      resources :columns, only: :show
    end
  end

  resource :session do
    scope module: :sessions do
      resource :magic_link
      resource :menu
      resource :passkey, only: :create
    end
  end

  get "/signup", to: redirect("/signup/new")

  resource :signup, only: %i[ new create ] do
    collection do
      scope module: :signups, as: :signup do
        resource :completion, only: %i[ new create ]
      end
    end
  end

  resource :landing

  namespace :my do
    resource :passkey_challenge, only: :create
    resource :identity, only: :show
    resources :passkeys, except: %i[ show new ]
    resource :timezone
    resource :menu
  end

  namespace :prompts do
    resources :cards
  end

  resolve "Note" do |note, options|
    options[:anchor] = ActionView::RecordIdentifier.dom_id(note)
    route_for :card, note.card, options
  end

  resolve "Event" do |event, options|
    polymorphic_url(event.eventable, options)
  end

  # Support for legacy URLs
  get "/collections/:collection_id/cards/:id", to: redirect { |params, request| "#{request.script_name}/cards/#{params[:id]}" }
  get "/collections/:id", to: redirect { |params, request| "#{request.script_name}/boards/#{params[:id]}" }

  get "up", to: "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "pwa#service_worker"
end
