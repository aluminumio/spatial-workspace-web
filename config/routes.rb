Rails.application.routes.draw do
  root "workspace#index"

  get "health", to: "health#show"

  post "api/command", to: "api#command"
  post "api/transcription", to: "api#transcription"
end
