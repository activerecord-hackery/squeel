module SqueelHelper
  def dsl(&block)
    Squeel::DSL.eval(&block)
  end

  def queries_for
    $queries_executed = []
    yield
    $queries_executed
  ensure
    %w{ BEGIN COMMIT }.each { |x| $queries_executed.delete(x) }
  end

  def new_join_dependency(*args)
    if defined?(ActiveRecord::Associations::JoinDependency)
      ActiveRecord::Associations::JoinDependency.new(*args)
    else
      ActiveRecord::Associations::ClassMethods::JoinDependency.new(*args)
    end
  end
end