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
end