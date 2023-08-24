describe Fastlane::Actions::AndroidTestlabScriptSwitAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The android_testlab_script_swit plugin is working!")

      Fastlane::Actions::AndroidTestlabScriptSwitAction.run(nil)
    end
  end
end
