module SqueelHelper
  def dsl(&block)
    Squeel::DSL.evaluate(&block)
  end
end