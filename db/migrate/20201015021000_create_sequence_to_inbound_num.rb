class CreateSequenceToInboundNum < ActiveRecord::Migration[5.1]

  def self.up
    execute <<-SQL
      create sequence inbound_num_seq increment by 1 minvalue 1 MAXVALUE 9999 start with 1 CYCLE
    SQL
  end

  def self.down
    execute <<-SQL
      drop  sequence inbound_num_seq
    SQL
  end

end
