require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class AndroidTestlabScriptSwitHelper
      # class methods that you define here become available in your action
      # as `Helper::AndroidTestlabScriptSwitHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the android_testlab_script_swit plugin helper!")
      end
    end
  end
end
