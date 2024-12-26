require 'spec_helper'

describe Searchlogic::CoreExt::Object do
  it "should accept and pass the argument to the searchlogic_options" do
    bl = searchlogic_lambda(:integer, :test => :value) { |value| {:conditions => ["id > ?", value]} }
    bl.searchlogic_options[:type].should == :integer
    bl.searchlogic_options[:test].should == :value
  end
end
