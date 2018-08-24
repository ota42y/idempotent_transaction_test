class IdempotentExecutor < ApplicationRecord
  enum transaction_type: [:setup, :example]
end
