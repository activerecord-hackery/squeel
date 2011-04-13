module SqueelHelper
  def dsl(&block)
    Squeel::DSL.eval(&block)
  end
end