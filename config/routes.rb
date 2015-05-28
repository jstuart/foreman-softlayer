Rails.application.routes.draw do
  match 'new_action', to: 'foreman_softlayer/hosts#new_action'
end
