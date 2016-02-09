# Doorman:
## Puppet Code Validation as a service

Doorman is a simple web service that accepts arbitrary code submissions and
validates it the way `puppet parser validate` would. It can optionally also
run `puppet-lint` checks on the code and display both results together.

Doorman is completely themeable, albeit rather primitively.

### Usage:

#### Running the service directly

    doorman [-p <port>] [-l [logfile]] [-t <themedir>] [-d]
     ↳ Runs the Doorman Puppet code validation service.

This is the simplest way to run Doorman. It has no external dependencies, other
than the handful of gems it uses. This command will start the service. It will
not daemonize itself, though a `systemd` init script is provided that will take
care of that for you. It will default to running on port 9000, and will serve
content directly out of its installation directory. You can override and customize
the web content by passing the `-t` or `--theme` command-line argument. See
[Creating your own theme](#creating-your-own-theme) below.

Options:

    -d, --debug                      Display or log debugging messages
    -l, --logfile [LOGFILE]          Path to logfile. Defaults to no logging, or
                                        /var/log/doorman if no filename is passed.
    -p, --port PORT                  Port to listen on. Defaults to 9000.
    -t, --theme THEMEDIR             Path to the theme directory.

    -h, --help                       Displays this help

#### Integrating with Middleware

If you plan to run this as a public service, then you may want to run it under
middleware, such as Phusion Passenger, for performance and scalability. The
specific implementation will depend on your choice of webserver and middleware.

To configure Doorman on Apache and Passenger, you'll need to
<a href="https://www.phusionpassenger.com/library/install/apache/install/oss/el7/">
install and configure the appropriate packages</a>. Then you'll need to configure
a virtual host to contain the application.

``` Apache
# /etc/httpd/conf.d/doorman.conf
Listen 9090
<VirtualHost *:9090>
    ServerName 54.201.129.11
    DocumentRoot /etc/doorman/public
    <Directory /etc/doorman/public>
        Require all granted
        Allow from all
        Options -MultiViews
    </Directory>
</VirtualHost>
```

The ``DocumentRoot` and `Directory` directives can point directly to the `public`
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
# /etc/doorman/config.ru
require 'rubygems'
require 'doorman'

logger       = Logger.new('/var/log/doorman')
logger.level = Logger::WARN

Doorman.set :root, File.dirname(__FILE__)
Doorman.set :logger, logger

run Doorman
```

#### Creating your own theme

Creating a Doorman theme is as simple as copying the content files to a directory
and customizing them. The `init` subcommand will do this for you. Note that the
command *will overwrite* existing files, but it will warn you before it does so.

    root@master:~ # mkdir /etc/doorman
    root@master:~ # cd /etc/doorman/
    root@master:/etc/doorman # doorman init
    Initializing directory as new Doorman theme...
    root@master:/etc/doorman # tree
    .
    ├── LICENSE
    ├── README.md
    ├── config.ru
    ├── public
    │   ├── info.png
    │   ├── prism-default.css
    │   ├── prism.js
    │   ├── styles.css
    │   └── testing.html
    └── views
        ├── index.erb
        └── result.erb

Once you've created your theme, you can start the Doorman service using the `-t`
or `--theme` command line arguments to tell Doorman where to find your content.

    root@master:~ # doorman -t /etc/doorman/

Alternatively, you can edit your webserver virtual host configuration to point
to the *public* directory within your new theme, as in the example shown above.
