class ApplicationRecord < ActiveRecord::Base
  include AfterCommitSideEffects

  primary_abstract_class
end
