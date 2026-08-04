Rails.application.routes.draw do
  resources :conversations, only: %i[index show create] do
    resources :messages, only: %i[create]
  end

  resources :standing_intents, only: %i[index new create destroy]

  get "dashboard", to: "dashboard#index"

  root to: redirect("/conversations")

  get "healthcheckz", to: proc { [200, {}, ["OK"]] }
end
