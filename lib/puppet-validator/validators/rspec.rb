class PuppetValidator::Validators::Rspec

  def initialize(settings)
    @logger   = settings.logger
    @spec_dir = settings.spec
  end

  def validate(str, spec)
    run_rspec("#{@spec_dir}/#{spec}.rb", str)
  end

private
  def run_rspec(spec_path, str)
    require 'rspec/core'

    # rspec needs an IO object to write to. We just want it as a string...
    data = StringIO.new
    RSpec::configure do |c|
      c.output_stream = data
      c.formatter     = 'json'
    end

    # require *after* setting the output stream or it screams at us
    # String input depends on https://github.com/rodjek/rspec-puppet/pull/619
    require 'rspec-puppet'
    RSpec::configure do |c|
      c.string        = str
      c.default_facts = {
        :ipaddress                 => '127.0.0.1',
        :kernel                    => 'Linux',
        :operatingsystem           => 'CentOS',
        :operatingsystemmajrelease => '7',
        :osfamily                  => 'RedHat',
      }

      # neuter functions that might run code on the master during compilation
      c.before(:each) do
        Puppet::Parser::Functions.newfunction(:generate, :type => :rvalue) { |args|
          true
        }
        Puppet::Parser::Functions.newfunction(:template, :type => :rvalue) { |args|
          args.first
        }
        Puppet::Parser::Functions.newfunction(:inline_template, :type => :rvalue) { |args|
          args.first
        }
      end
    end

    begin
      raise(Errno::ENOENT, "Spec path #{spec_path} does not exist") unless File.file? spec_path

      RSpec::Core::Runner.run([spec_path])
      parse_output(data.string)

    rescue StandardError, LoadError => e
      @logger.error e.message
      @logger.debug e.backtrace

      {
        'success' => false,
        'errors' => ["Unknown validator error: #{e.message}"],
      }.to_json
    end
  end

  def parse_output(data)
    begin
      result = JSON.parse(data)
      errors = result['examples']
                 .select  {|example| example['status'] == 'failed' }
                 .collect {|example| example['full_description']   }

      output = {
        'success' => errors.empty?,
        'errors'  => errors,
      }
    rescue => e
      output = {
        'success' => false,
        'errors' => ["Unparseable RSpec output: #{e.message}"],
      }
      @logger.error e.message
      @logger.debug e.backtrace
    end

    output
  end

end
