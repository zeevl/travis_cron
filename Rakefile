require "yaml"
require "base64"

$LOAD_PATH << "lib"
require "singleton_class"
require "travis_cron"



desc "run tests"
task :default do
  sh "rspec spec"
end

desc "report"
task :cron do
  TravisCron.run(TravisCron.config)
end
