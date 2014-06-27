# Background
I had a number of Docker containers that I wanted to run with a slightly different configuration, depending on the environment I was launching them. For example, a web application might connect to a different database in a staging environment, or a MongoDB replica set name might be different. This meant my options basically looked like:

* Maintain multiple containers / Dockerfiles.
* Maintain the configuration in separate data volumes and use --volumes-from to pull the relevant container in.
* Bundle the configuration files into one container, and manually specify the `CMD` or `ENTRYPOINT` values to pick this up. 

None of those really appealed due to duplication, or the complexity of an approach that would necessitate really long `docker run` commands. 

So I knocked up a quick Ruby script (imaginatively called "Runner.rb") that I could use across all my containers, which does the following :

* Generates configuration files from ERB templates 
* Uses values provided in YAML files, one per environment
* Copies the generated templates to the correct location and specifies permissions
* Executes a replacement process once it's finished (e.g. mongod, nginx, supervisord, etc.)

This way I can keep all my configuration together in the container, and just tell Docker which environment to use when I start it. 

# Usage
Runner.rb can be used to dynamically generate configuration files before passing execution over to a daemon process. 

It looks at an environment variable called "environment", and creates a set of configuration files based on ERB templates, and then runs a specified daemon process via `exec`. Usually, when running a container that users Runner.rb, all you need to do is pass the environment to it, e.g. 

	# docker run -t -i -e environment=staging markround/demo_container:latest
	Runner.rb v0.0.1
	Using runner configuration from /etc/runner
	Using environment staging
	Parsing /etc/runner/templates/mongodb.conf.erb
	Setting ownerships and privileges on /etc/mongodb.conf
	Template generation completed, about to exec replacement process.
	Calling /usr/bin/supervisord...

If no environment is specified, it will default to using "production".

# Setup

Firstly, copy the runner script and set your Dockerfile to use it :

	ADD data/runner.rb /usr/local/bin/runner.rb
	...
	... Rest of Dockerfile here
	...
	CMD /usr/local/bin/runner.rb

Now, set up your configuration. By default, Runner.rb looks for configuration under `/etc/runner`, but this can be set to somewhere else by setting the environment variable `runner_base`. This is particularly useful for testing purposes, e.g.

	$ runner_base=$PWD/runner ./runner.rb

Runner.rb expects a directory structure like this (using /etc/runner as it's base) :

	etc
	└── runner
	    ├── common.yaml
	    │
	    ├── environments
	    │   ├── production.yaml
	    │   ├── staging.yaml
	    │   ...
	    │   ... other environments defined here
	    │   ...
	    │
	    └── templates
	        ├── properties.json.erb
	        ├── mongodb.conf.erb
	        ...
	        ... other configuration file templates go here
	        ...

It is suggested that you add all this under your Docker definition in a `data/runner` base directory (e.g. data/runner/common.yaml, data/runner/environments and so on...) and then add it in your Dockerfile :

	ADD data/runner /etc/runner

## Common configuration
`common.yaml` just currently contains the `exec` parameter. This is simply what will be executed after the configuration files have been generated. Example:

	exec: /usr/bin/supervisord

## Environment configuration

These files are named after the environment variable `environment` that you pass in using `docker run -e`. They define the templates to be parsed, where the generated configuration file should be installed, ownership and permission information, and a set of key:value pairs that are pulled into the `config` hash for use by the ERB template. 

Example: In your <environment>.yaml file, let's assume you want to define some parameters for an application. For example, assume you wanted to use a different MongoDB replica set name in your staging environment. Here's how you might set the replica set name in your `staging.yaml` environment file :

	mongodb.conf.erb:
	  target: /etc/mongodb.conf
	  user: root
	  group: root
	  perms: 0644
	  config:
	    replSet: 'stage'

And then your `production.yaml` (which everything will use if you don't specify an environment) might contain the defaults :

	mongodb.conf.erb:
	  target: /etc/mongodb.conf
	  config:
	    replSet: 'production'

Note that if you omit the user/group/perms parameters, the defaults are root:root, 0644. Also, if you don't run the script as root, it will skip setting these.

## Template files

These are simply the ERB templates for your configuration files, and are populated with values from the selected environment file. When the environment configuration is parsed (see above), key:value pairs are placed in the `config` hash. Using MongoDB as an example again, you'd have a `/etc/runner/templates/mongodb.conf.erb` with the following content:

	... (rest of content snipped) ...
	
	# in replica set configuration, specify the name of the replica set
	<% if (config['replSet']) %>
	replSet = <%= config['replSet'] %>
	<% end %> 
	
	... (rest of content snipped) ...

	
Which, when run through Runner.rb/Docker with `-e environment=staging`, produces the following :

	# in replica set configuration, specify the name of the replica set
	replSet = stage
	
Or, if no environment is specified :

	# in replica set configuration, specify the name of the replica set
	replSet = production

# Future improvements

* Add an etcd backend.
* Anything else ?

# License

MIT. See the included LICENSE file.


