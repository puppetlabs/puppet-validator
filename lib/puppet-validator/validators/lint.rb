require 'puppet-lint'

class PuppetValidator::Validators::Lint
  def initialize(settings)
    @logger   = settings.logger
    @disabled = settings.disabled_lint_checks
  end

  # This global configuration means it's a race condition.
  # TODO: We should isolate this.
  def validate(data, checks = nil)
    begin
      if checks
        @logger.info "Disabling checks: #{(PuppetValidator::Validators::Lint.all_checks - checks).inspect}"

        checks.each do |check|
          PuppetLint.configuration.send("enable_#{check}")
        end

        (PuppetValidator::Validators::Lint.all_checks - checks).each do |check|
          PuppetLint.configuration.send("disable_#{check}")
        end
      else
        @logger.info "Disabling checks: #{@disabled.inspect}"

        @disabled.each do |check|
          PuppetLint.configuration.send("disable_#{check}")
        end
      end

      linter = PuppetLint.new
      linter.code = data
      linter.run
      linter.print_problems
      linter.problems
    rescue => detail
      @logger.warn detail.message
      []
    end
  end

  def self.all_checks
    # sanitize because reasonss
    PuppetLint.configuration.checks.map {|check| check.to_s}
  end

end
