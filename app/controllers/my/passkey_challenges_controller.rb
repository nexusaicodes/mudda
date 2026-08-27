class My::PasskeyChallengesController < ActionPack::Passkey::ChallengesController
  include Authentication
  include Authorization

  allow_unauthenticated_access
end
