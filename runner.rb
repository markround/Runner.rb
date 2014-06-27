#!/usr/bin/env ruby
# Dynamic configuration generator for Docker
# Mark Round <github@markround.com>
VERSION="0.0.1"

require "erb"
require "yaml"
require "fileutils"

# Set this environment variable if you want to debug a configuration in a temporary directory.
# EG: $ runner_base=/tmp/runner ./runner.rb
runner_base = (ENV['runner_base'].nil?) ? '/etc/runner' : ENV['runner_base']

# Default environment is production 
environment = (ENV['environment'].nil?) ? 'production' : ENV['environment']

puts "Runner.rb v#{VERSION}"
puts "Using runner configuration from #{runner_base}"
puts "Using environment #{environment}"

common_config=YAML::load(open(File.join(runner_base , "common.yaml")))
environment_config=YAML::load(open(File.join(runner_base , "environments" , environment + ".yaml")))

environment_config.each do |template, params|
	template_file = File.join(runner_base , "templates" , template)
	puts "Parsing #{template_file}"
	template = open(template_file).read
	config = params['config']
	generated = ERB.new(template).result(binding)

	target_file = params['target']

	target = open(target_file , "w")
	target.puts(generated)
	target.close

	if Process::Sys.geteuid == 0 then
		puts "Setting ownerships and privileges on #{target_file}"
		user        = params['user'].nil?  ? 'root' : params['user']
		group       = params['group'].nil? ? 'root' : params['group']
		perms       = params['perms'].nil? ?  0644  : params['perms']
		FileUtils.chmod(perms , target_file)
		FileUtils.chown(user , group , target_file)
	else
		puts "Not running as root, so not setting ownership/permissions for #{target_file}"
	end
end

puts "Template generation completed, about to exec replacement process."
puts "Calling #{common_config['exec']}..."
exec(common_config['exec'])
