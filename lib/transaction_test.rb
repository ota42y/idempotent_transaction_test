User.destroy_all

users = Array.new(3) { |i| User.create(name: "user_#{i}") }

executors = users.map { |u| Array.new(10000) { u.idempotent_executors.new(transaction_type: :setup, signature: SecureRandom.uuid) } }.flatten
IdempotentExecutor.import executors

users.each do |u|
  u.idempotent_executors.create(transaction_type: :setup, signature: 'aaaa')
  u.idempotent_executors.create(transaction_type: :setup, signature: 'bbbb')
  u.idempotent_executors.create(transaction_type: :example, signature: 'cccc')
end

user_ids = users.map(&:id)

config = Rails.configuration.database_configuration["development"]
client_1 = Mysql2::Client.new(config)
client_2 = Mysql2::Client.new(config)
client_3 = Mysql2::Client.new(config)

def signatures(client, limit, offset)
  client.query("SELECT signature FROM idempotent_executors ORDER BY id LIMIT #{limit} OFFSET #{offset};").to_a.map{ |row| row['signature'] }
end

# client 1
binding.pry
start_signatures = ['bbbb', 'cccc']
offset = executors.size + 9 - 2
raise 'invalid data' unless signatures(client_1, 2, offset) == start_signatures

client_1.query('start transaction;')
query = "INSERT INTO idempotent_executors (user_id, transaction_type, signature, created_at, updated_at) VALUES (#{user_ids.first}, 1, 'abc', '2016-04-01 16:00:00', '2016-04-01 16:00:00');"
client_1.query(query)

raise 'invalid data' unless signatures(client_1, 3, offset) == start_signatures + ['abc']

# client 2
# client 1 insert in transaction, so client 2 can't see it
raise 'invalid data' unless signatures(client_2, 2, offset) == start_signatures

client_2.query('start transaction;')
query = "INSERT INTO idempotent_executors (user_id, transaction_type, signature, created_at, updated_at) VALUES (#{user_ids.first}, 1, 'abcd', '2016-04-01 16:00:00', '2016-04-01 16:00:00');"
client_2.query(query) # not locked

raise 'invalid data' unless signatures(client_2, 3, offset) == start_signatures + ['abcd']


# client 3
# same query for client 1

query = "INSERT INTO idempotent_executors (user_id, transaction_type, signature, created_at, updated_at) VALUES (#{user_ids.first}, 1, 'abc', '2016-04-01 16:00:00', '2016-04-01 16:00:00');"
client_3.query(query, async: true) # lock wait
begin
  signatures(client_3, 10, 7)
  raise 'should raise error'
rescue => e
  raise 'invalid error' unless e.message == "This connection is still waiting for a result, try again once you have the result"
end

client_1.query('commit')
raise 'invalid data' unless signatures(client_1, 3, offset) == start_signatures + ['abc']

raise 'invalid data' unless signatures(client_2, 3, offset) == start_signatures + ['abcd']
client_2.query('commit')

raise 'invalid data' unless signatures(client_1, 4, offset) == start_signatures + ['abc', 'abcd']
raise 'invalid data' unless signatures(client_2, 4, offset) == start_signatures + ['abc', 'abcd']

begin
  client_3.async_result
rescue Mysql2::Error => e
  raise 'invalid error' unless e.message.starts_with?('Duplicate entry') && e.message.end_with?("for key 'idempotent_index'")
end

