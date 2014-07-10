require 'rest_client'
require 'json'
require 'sentry-raven'



module TravisCron
  class << self
    # configure self from env or config.yml
    def config
      config = if encoded = ENV['CONFIG_YML']
        require 'base64'
        Base64.decode64(encoded)
      else
        File.read('config.yml')
      end
      YAML.load(config)[env].freeze
    end

    def env
      ENV['RAILS_ENV'] || 'development'
    end

    def run(config)
      Raven.configure { |c| c.dsn = config['sentry_dsn'] } if config['sentry_dsn']
      Raven.capture do
        config.fetch("projects").each do |project|
          project["token"] ||= config["token"] # support default token
          result = restart_build(project)
          puts "#{project["url"]} #{project["branch"] && '-' + project["branch"]}: #{result}"
        end
      end
    end

    private

    def restart_build(project)
      auth = {:Authorization => %{token "#{project.fetch("token")}"}}

      scheme, _, host, path = project.fetch("url").split("/", 4)
      base = "#{scheme}//api.#{host.split(".").last(2).join(".")}"
      branch = project["branch"]

      result = RestClient.get("#{base}/repos/#{path}/builds", auth)
      build = JSON.load(result).detect { |p| branch.nil? || p["branch"] == branch }
      raise "No build found for branch #{branch}" unless build
      last_build_id = build["id"]

      result = RestClient.post("#{base}/requests", {"build_id" => last_build_id}, auth)
      result = JSON.load(result)

      raise "Failed to restart build! #{result["flash"][0]["error"]}}" unless result['result']

      result['result']
    end
  end
end
