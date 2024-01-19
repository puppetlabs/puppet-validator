# Puppet Validator:
## Puppet Code Validation as a service

Puppet Validator is a simple web service that accepts arbitrary code submissions
and validates it the way `puppet parser validate` and `puppet-lint` would. For
simple and self-contained manifests, it can also show you a relationship graph.

Puppet Validator is completely themeable, albeit rather primitively.

An example site had been running on https://validate.puppet.com but is now in the process of being migrated to a new location.
Follow the below instructions to run locally until this work takes place.

### Usage:

#### Running the service directly

    puppet-validator [-p <port>] [-l [logfile]] [-t <themedir>] [-d]
     ↳ Runs the Puppet Validator code validation service.

This is the simplest way to run Puppet Validator. It has no external dependencies, other
than the handful of gems it uses. This command will start the service. It will
not daemonize itself, though a [`systemd` init script is provided](#running-standalone-with-systemd)
that will take care of that for you. It will default to running on port 9000,
and will serve content directly out of its installation directory. You can
override and customize the web content by passing the `-t` or `--theme`
command-line argument. See [Creating your own theme](#creating-your-own-theme) below.

This can load code from several popular paste services and can gist validated
code to https://gist.github.com. These gists include a `referer` link back so
the gisted code can be re-validated at any time. If you'd like the `referer`
check to work properly, make sure to run this with a valid SSL certificate.

Options:

    -d, --debug                      Display or log debugging messages
        --disable DISABLED_CHECKS    Lint checks to disable. Either comma-separated list or filename.
    -l, --logfile [LOGFILE]          Path to logfile. Defaults to no logging, or /var/log/puppet-validator if no filename is passed.
    -p, --port PORT                  Port to listen on. Defaults to 9000.
    -t, --theme THEMEDIR             Path to the theme directory.
    -x, --csrf                       Protect from cross site request forgery. Requires code to be submitted for validation via the webpage.
    -g, --graph                      Generate relationship graphs from validated code. Requires `graphviz` to be installed.
        --ssl                        Run with SSL support. Autogenerates a self-signed certificates by default.
        --ssl-cert FILE              Specify the SSL certificate you'd like use use. Pair with --ssl-key.
        --ssl-key FILE               Specify the SSL key file you'd like use use. Pair with --ssl-cert.

    -h, --help                       Displays this help


#### Integrating with Middleware

If you plan to run this as a public service, then you may want to run it under
middleware (such as Phusion Passenger, Puma, or Unicorn) for performance and
scalability. The specific implementation will depend on your choice of webserver
and middleware.

To configure Puppet Validator on Apache and Passenger, you'll need to
<a href="https://www.phusionpassenger.com/library/install/apache/install/oss/el7/">
install and configure the appropriate packages</a>. Then you'll need to configure
a virtual host to contain the application.

``` Apache
# /etc/httpd/conf.d/puppet-validator.conf
Listen 9090
<VirtualHost *:9090>
    ServerName 54.201.129.11
    DocumentRoot /etc/puppet-validator/public
    <Directory /etc/puppet-validator/public>
        Require all granted
        Allow from all
        Options -MultiViews
    </Directory>
</VirtualHost>
```

The `DocumentRoot` and `Directory` directives can point directly to the `public`
directory *within the gem installation directory*, or it can point to the `public`
directory of a custom theme you've created. See
[Creating your own theme](#creating-your-own-theme) below. The two directives
should point to the same directory.

In the directory directly above the `public` directory referenced above, you
should have a `config.ru` file. This file will actually bootstrap and start the
application. An example file exists in the root of the gem installation directory.
It looks similar to the file below and may be customized to pass in any options
you'd like.

``` Ruby
# /etc/puppet-validator/config.ru
require 'rubygems'
require 'puppet-validator'

logger       = Logger.new('/var/log/puppet-validator')
logger.level = Logger::WARN

PuppetValidator.set :root, File.dirname(__FILE__)
PuppetValidator.set :logger, logger

# List out the lint checks you want disabled. By default, this will enable
#   all installed checks. puppet-lint --help will list known checks.
#
PuppetValidator.set :disabled_lint_checks, ['80chars']

# Protect from cross site request forgery. With this set, code may be
#   submitted for validation by the website only.
#
PuppetValidator.set :csrf, false

# Provide the option to generate relationship graphs from validated code.
#   This requires that the `graphviz` package be installed.
#
PuppetValidator.set :graph, false

run PuppetValidator
```

#### Creating your own theme

Creating a Puppet Validator theme is as simple as copying the content files to a directory
and customizing them. The `init` subcommand will do this for you. Note that the
command *will overwrite* existing files, but it will warn you before it does so.

    root@master:~ # mkdir /etc/puppet-validator
    root@master:~ # cd /etc/puppet-validator/
    root@master:/etc/puppet-validator # puppet-validator init
    Initializing directory as new Puppet Validator theme...
    root@master:/etc/puppet-validator # tree -L 2
    .
    ├── LICENSE
    ├── README.md
    ├── config.ru
    ├── public
    │   ├── font-awesome-4.7.0
    │   ├── gist.png
    │   ├── relationships.html
    │   ├── scripts.js
    │   ├── styles.css
    │   ├── testing.html
    │   └── validation.js
    └── views
        ├── index.erb
        └── result.erb

Once you've created your theme, you can start the Puppet Validator service using the `-t`
or `--theme` command line arguments to tell Puppet Validator where to find your content.

    root@master:~ # puppet-validator --theme /etc/puppet-validator/

Alternatively, you can edit your webserver virtual host configuration to point
to the *public* directory within your new theme, as in the example shown above.

#### Disabling `puppet-lint` checks

Puppet-lint is an incredibly valuable tool. That said, some of the checks it runs
may not apply to your environment. It's easy to disable these checks, either on
the command-line, or in the `config.ru` file. By default, Puppet Validator will just run
all available checks.

Checks can be disabled either as a comma-separated list of checks:

    root@master:~ # puppet-validator --disable 80chars,double_quoted_strings

Or in a file with one check per line.

    root@master:~ # puppet-validator --disable /etc/puppet-validator/disabled_checks
    root@master:~ # cat /etc/puppet-validator/disabled_checks
    80chars
    double_quoted_strings

This can also be done in your `config.ru`. Specifying a list would look like this:

``` Ruby
PuppetValidator.set :disabled_lint_checks, ['80chars', 'double_quoted_strings']

```

And loading the disabled checks from a file would look like:

``` Ruby
PuppetValidator.set :disabled_lint_checks, '/etc/puppet-validator/disabled_checks'

```

#### Validating code against multiple Puppet versions

Puppet Validator runs a new process to validate each submission. This means that
it can lazy-load the requested Puppet version on demand. Simply `gem install` all
the versions you want and they'll be visible in the drop-down selector.

    # Installing a specific version
    root@master:~ # gem install puppet -v 5.3.3

    # Installing several versions at once
    root@master:~ # gem install puppet:3.8.8 puppet:4.10.0 puppet:5.3.3

If you use the `puppet_validator` module, simply specify the versions you want
as an array,

#### Running standalone with `systemd`

A simple `systemd` init script might look something like:

    # /usr/lib/systemd/system/puppet-validator.service
    [Unit]
    Description=Puppet Validator
    After=network.target

    [Service]
    ExecStart=puppet-validator
    Restart=on-failure
    KillSignal=SIGINT

    [Install]
    WantedBy=multi-user.target

Customize the command line as needed. You might include a `--theme` or `--port`
argument, or you might provide the full path to an `rvm` installed gem.

### Bookmarklet

If you just want to validate Puppet code you see on a website, follow the
instructions on http://binford2k.com/content/2016/06/puppetlinter-dot-com

