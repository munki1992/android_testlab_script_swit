require 'fastlane/action'
require 'json'
require 'fileutils'
require 'open-uri'
require 'httparty'

module Fastlane
  module Actions
    class AndroidTestlabScriptSwitAction < Action

        def self.measure_time
          start_time = Time.now
          yield
          end_time = Time.now
          duration_sec_total = (end_time - start_time).round(1)
          duration_min = (duration_sec_total / 60).round(1)
          duration_sec = duration_sec_total % 60
          return "#{duration_min}분 소요시간 자동화"
      end
        
      # actions run
      def self.run(params)
        UI.message("********************************")
        UI.message("Start Action")
        UI.message("********************************")
        
        duration = measure_time do
            
            # Result Bucket & Dir
            results_bucket = params[:firebase_test_lab_results_bucket] || "#{params[:project_id]}_test_results"
            results_dir = params[:firebase_test_lab_results_dir] || "firebase_test_result_#{DateTime.now.strftime('%Y-%m-%d-%H:%M:%S')}"

            # Set Target Project ID
            Helper.config(params[:project_id])

            # Activate service account
            Helper.authenticate(params[:gcloud_key_file])

            # RoboScriptOption
            robo_script_option = params[:robo_script_path].nil? ? "" : "--robo-script #{params[:robo_script_path]} "
            
            # Run Firebase Test Lab
            Helper.run_tests(params[:gcloud_components_channel], "--type #{params[:type]} "\
                      "--app #{params[:app_apk]} "\
                      "#{"--test #{params[:app_test_apk]} " unless params[:app_test_apk].nil?}"\
                      "#{"--use-orchestrator " if params[:type] == "instrumentation" && params[:use_orchestrator]}"\
                      "#{params[:devices].map { |d| "--device model=#{d[:model]},version=#{d[:version]},locale=#{d[:locale]},orientation=#{d[:orientation]} " }.join}"\
                      "--timeout #{params[:timeout]} "\
                      "--results-bucket #{results_bucket} "\
                      "--results-dir #{results_dir} "\
                      "#{params[:extra_options]} "\
                      "#{robo_script_option}"\
                      "--format=json 1>#{Helper.if_need_dir(params[:console_log_file_name])}"
            )
            
            # Fetch results
            download_dir = params[:download_dir]
            if download_dir
              UI.message("Fetch results from Firebase Test Lab results bucket")
              json.each do |status|
                axis = status["axis_value"]
                Helper.if_need_dir("#{download_dir}/#{axis}")
                Helper.copy_from_gcs("#{results_bucket}/#{results_dir}/#{axis}", download_dir)
                Helper.set_public("#{results_bucket}/#{results_dir}/#{axis}")
              end
            end
            
        end
        
        # Swit Result PayLoad
        swit_device_payload = ""

        # Swit Send PayLoad - 테스트 시간 추가
        swit_webhook_payload = params[:swit_webhook_payload][0..-5] + ','
        swit_webhook_payload += "{\"type\":\"rt_section\",\"indent\":1,\"elements\":[{\"type\":\"rt_text\",\"content\":\"테스트 시간 : #{duration}\"}]},"

        # Firebase Test Lab Result Json
        resultJson = JSON.parse(File.read(params[:console_log_file_name]))

        swit_device_payload = resultJson.map.with_index do |item, device_index|
          axis_value_parts = item["axis_value"].split('-')
          outcome = item["outcome"]

          model = axis_value_parts[0]
          version = axis_value_parts[1]
          locale = axis_value_parts[2]
          orientation = axis_value_parts[3]

          parts_payload = axis_value_parts.map do |part|
            "{\"type\":\"rt_section\",\"indent\":2,\"elements\":[{\"type\":\"rt_text\",\"content\":\"Part : #{part}\"}]}"
          end.join(',')

          device_payload = "{\"type\":\"rt_section\",\"indent\":1,\"elements\":[{\"type\":\"rt_text\",\"content\":\"Device#{device_index + 1}\"}]},{\"type\":\"rt_section\",\"indent\":2,\"elements\":[{\"type\":\"rt_text\", \"content\": \"model: #{model}\"},{\"type\":\"rt_text\", \"content\": \"version: #{version}\"},{\"type\":\"rt_text\", \"content\": \"locale: #{locale}\"},{\"type\":\"rt_text\", \"content\": \"orientation: #{orientation}\"},{\"type\":\"rt_text\", \"content\": \"Outcome: #{outcome}\"}]}"

        end.join(',')

        swit_device_payload.chomp!(',')

        # Swit PayLoad 병합
        swit_webhook_payload += swit_device_payload + ']}]}'
        
        # 마지막 체크
        UI.message(swit_webhook_payload)
         
        # Swit WebHook
        HTTParty.post(params[:swit_webhook_url], body: { body_text: swit_webhook_payload }.to_json, headers: { 'Content-Type' => 'application/json' })

        UI.message("********************************")
        UI.message("Finish Action")
        UI.message("********************************")
      end

      # Short Detils
      def self.description
        "Android Firebase TestLab with Robo Script Test"
      end

      # Authors
      def self.authors
        ["나비이쁜이"]
      end

      def self.return_value
        ["Authenticates with Google Cloud.",
         "Runs tests in Firebase Test Lab.",
         "Fetches the results to a local directory."].join("\n")
      end

      # Long Detils
      def self.details
        "This plug-in uses Firebase TestLab. You can also include RoboScript files."
      end

      # Option val
      def self.available_options
        [
            # project_id (true)
            FastlaneCore::ConfigItem.new(key: :project_id,
                                         env_name: "PROJECT_ID",
                                         description: "Your Firebase project id",
                                         is_string: true,
                                         optional: false),

            # gcloud_key_file (true)
            FastlaneCore::ConfigItem.new(key: :gcloud_key_file,
                                         env_name: "GCLOUD_KEY_FILE",
                                         description: "File path containing the gcloud auth key. Default: Created from GCLOUD_SERVICE_KEY environment variable",
                                         is_string: true,
                                         optional: false),

            # test type (true)
            FastlaneCore::ConfigItem.new(key: :type,
                                         env_name: "TYPE",
                                         description: "Test type. Default: robo (robo/instrumentation)",
                                         is_string: true,
                                         optional: true,
                                         default_value: "robo",
                                         verify_block: proc do |value|
                                           if value != "robo" && value != "instrumentation"
                                             UI.user_error!("Unknown test type.")
                                           end
                                         end),

            # device (true)
            FastlaneCore::ConfigItem.new(key: :devices,
                                         description: "Devices to test the app on",
                                         type: Array,
                                         default_value: [{
                                                            model: "Nexus6",
                                                            version: "21",
                                                            locale: "en_US",
                                                            orientation: "portrait"
                                                         }],
                                         verify_block: proc do |value|
                                           if value.empty?
                                             UI.user_error!("Devices cannot be empty")
                                           end
                                           value.each do |current|
                                             if current.class != Hash
                                               UI.user_error!("Each device must be represented by a Hash object, " \
                                                 "#{current.class} found")
                                             end
                                             check_has_property(current, :model)
                                             check_has_property(current, :version)
                                             set_default_property(current, :locale, "en_US")
                                             set_default_property(current, :orientation, "portrait")
                                            end
                                         end),

            # timeout (ture)
            FastlaneCore::ConfigItem.new(key: :timeout,
                                         env_name: "TIMEOUT",
                                         description: "The max time this test execution can run before it is cancelled. Default: 5m (this value must be greater than or equal to 1m)",
                                         type: String,
                                         optional: false,
                                         default_value: "3m"),

            # apk (true)
            FastlaneCore::ConfigItem.new(key: :app_apk,
                                         env_name: "APP_APK",
                                         description: "The path for your android app apk",
                                         type: String,
                                         optional: false),

            # swit_webhook url (false)
            FastlaneCore::ConfigItem.new(key: :swit_webhook_url,
                                         env_name: "SWIT_WEBHOOK_URL",
                                         description: "The Swit WebHOOK URL",
                                         type: String,
                                         optional: true),

            # swit_webhook payload (false)
            FastlaneCore::ConfigItem.new(key: :swit_webhook_payload,
                                         env_name: "SWIT_WEBHOOK_PAYLOAD",
                                         description: "The Swit WebHOOK PAYLOAD",
                                         type: String,
                                         optional: true),

            # test apk (false)
            FastlaneCore::ConfigItem.new(key: :app_test_apk,
                                         env_name: "APP_TEST_APK",
                                         description: "The path for your android test apk. Default: empty string",
                                         type: String,
                                         optional: true,
                                         default_value: nil),

            # orchestrator (false)
            FastlaneCore::ConfigItem.new(key: :use_orchestrator,
                                         env_name: "USE_ORCHESTRATOR",
                                         description: "If you use orchestrator when set instrumentation test. Default: false",
                                         type: Boolean,
                                         optional: true,
                                         default_value: false),

            # gcloud_components_channel (false)
            FastlaneCore::ConfigItem.new(key: :gcloud_components_channel,
                                         env_name: "gcloud_components_channel",
                                         description: "If you use beta or alpha components. Default stable (alpha/beta)",
                                         is_string: true,
                                         optional: true,
                                         default_value: "stable"),

            # console_log_file_name (false)
            FastlaneCore::ConfigItem.new(key: :console_log_file_name,
                                         env_name: "CONSOLE_LOG_FILE_NAME",
                                         description: "The filename to save the output results. Default: ./console_output.log",
                                         type: String,
                                         optional: true,
                                         default_value: "./console_output.log"),

            # extra_options (false)
            FastlaneCore::ConfigItem.new(key: :extra_options,
                                         env_name: "EXTRA_OPTIONS",
                                         description: "Extra options that you need to pass to the gcloud command. Default: empty string",
                                         type: String,
                                         optional: true,
                                         default_value: ""),

            # firebase_test_lab_results_bucket (false)
            FastlaneCore::ConfigItem.new(key: :firebase_test_lab_results_bucket,
                                         env_name: "FIREBASE_TEST_LAB_RESULTS_BUCKET",
                                         description: "Name of Firebase Test Lab results bucket",
                                         type: String,
                                         optional: true,
                                         default_value: nil),

            # firebase_test_lab_results_dir (false)
            FastlaneCore::ConfigItem.new(key: :firebase_test_lab_results_dir,
                                         env_name: "FIREBASE_TEST_LAB_RESULTS_DIR",
                                         description: "Name of Firebase Test Lab results directory",
                                         type: String,
                                         optional: true,
                                         default_value: nil),

            # download_dir (false)
            FastlaneCore::ConfigItem.new(key: :download_dir,
                                         env_name: "DOWNLOAD_DIR",
                                         description: "Target directory to download screenshots from firebase",
                                         type: String,
                                         optional: true,
                                         default_value: nil),

            # robo_script_path (false)
            FastlaneCore::ConfigItem.new(key: :robo_script_path,
                                         env_name: "ROBO_SCRIPT_PATH",
                                         description: "Path to Robo script JSON file",
                                         is_string: true,
                                         optional: true,
                                         verify_block: proc do |value|
                                         UI.user_error!("Couldn't find JSON file at path '#{value}'") unless File.exist?(value) end)
      ]
      end

      def self.check_has_property(hash_obj, property)
        UI.user_error!("Each device must have #{property} property") unless hash_obj.key?(property)
      end

      def self.set_default_property(hash_obj, property, default)
        unless hash_obj.key?(property)
          hash_obj[property] = default
        end
      end

      # android platform
      def self.is_supported?(platform)
        platform == :android
      end

      #
      def self.output
        [['console_output.log', 'A console log when running Firebase Test Lab with gcloud']]
      end

      def self.example_code

      end

    end
  end
end
