require 'test_plugin_helper'

class ForemanSoftlayerTest < ActiveSupport::TestCase
  setup do
    User.current = User.find_by_login 'admin'
  end

  test 'the truth' do
    assert true
  end

  test 'truth' do
    assert_kind_of Module, ForemanSoftlayer
  end
end
