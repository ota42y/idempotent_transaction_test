class User < ApplicationRecord
    has_many :posts, dependent: :destroy
    has_many :idempotent_executors, dependent: :destroy
end
