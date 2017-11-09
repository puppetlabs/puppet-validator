class PuppetValidator::Validators::Rspec

  def initialize(spec)
    @spec_dir = spec
  end

  def validate(str, spec)
    # rspec defines a crapton of global information and doesn't clean up well
    # between runs. This means that there are global objects that leak and chew
    # up memory. To counter that, we fork a process to run the spec test.
    reader, writer = IO.pipe
    output = nil

    if fork
      writer.close
      output = parse_output(reader.read)
      reader.close
      Process.wait
    else
      reader.close
      run_rspec("#{@spec_dir}/#{spec}.rb", str, writer)
      writer.close
      # if we fire any at_exit hooks, Sinatra has a kitten
      exit!
    end

    output
  end

private
  def run_rspec(spec_path, str, writer)
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
    end

    begin
      raise(Errno::ENOENT, "Spec path #{spec_path} does not exist") unless File.file? spec_path

      RSpec::Core::Runner.run([spec_path])
      writer.write(data.string)
    rescue StandardError, LoadError => e
      writer.write({
        'examples' => [
          {
            'status'      => 'failed',
            'description' => "Error running spec test: #{e.message}",
          }
        ]}.to_json)
    end
  end

  def parse_output(data)
    begin
      result = JSON.parse(data)
      errors = result['examples']
                 .select  {|example| example['status'] == 'failed' }
                 .collect {|example| example['description']        }

      output = {
        'success' => errors.empty?,
        'errors'  => errors,
      }
    rescue => e
      output = {
        'success' => false,
        'errors' => ["Unknown validator error: #{e.message}"],
      }
      puts e.backtrace
    end

    output
  end

end
