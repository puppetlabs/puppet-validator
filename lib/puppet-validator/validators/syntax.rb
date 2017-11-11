class PuppetValidator::Validators::Syntax

  def initialize(settings, version = nil)
    @logger = settings.logger

    # Set the version of Puppet to load
    if version
      @logger.warn "Loading Puppet version #{version}."
      gem('puppet', version)
    end
    # load in the constructor to avoid polluting the parent process
    require 'puppet'
    require 'puppet/parser'

    Puppet.initialize_settings rescue nil
    Puppet.settings[:app_management] = true if Gem::Version.new(Puppet.version) >= Gem::Version.new('4.3.2')

    # set up the base environment
    Puppet.push_context(Puppet.base_context(Puppet.settings), 'Setup for Puppet Validator') rescue nil

    # disable as much disk access as possible
    Puppet::Node::Facts.indirection.terminus_class = :memory
    Puppet::Node.indirection.cache_class = nil
  end

  def validate(data)
    begin
      Puppet[:code] = data

      if Puppet::Node::Environment.respond_to?(:create)
        validation_environment = Puppet::Node::Environment.create(:production, [])
        validation_environment.check_for_reparse
      else
        validation_environment = Puppet::Node::Environment.new(:production)
      end

      validation_environment.known_resource_types.clear

      {:status => true, :message => 'Syntax OK'}
    rescue => detail
      @logger.warn detail.message
      err = {:status => false, :message => detail.message}
      err[:line] = detail.line if detail.methods.include? :line
      err[:pos]  = detail.pos  if detail.methods.include? :pos
      err
    end
  end

  def render!
    require 'graphviz'

    begin
      raise 'No Puppet environment found' if Puppet[:code].empty?

      node    = Puppet::Node.indirection.find('validator')
      catalog = Puppet::Resource::Catalog.indirection.find(node.name, :use_node => node)

      # These calls are failing due to an internal method not being available in 2 & 3.x. Suspect
      # that it's related to the compiler not being set up fully?
      catalog.remove_resource(catalog.resource("Stage", :main)) rescue nil
      catalog.remove_resource(catalog.resource("Class", :settings)) rescue nil

      graph = catalog.to_ral.relationship_graph.to_dot
      svg   = GraphViz.parse_string(graph) do |graph|
        graph[:label] = 'Resource Relationships'

        graph.each_node do |name, node|
          next unless name.start_with? 'Whit'
          newname = name.dup
          newname.sub!('Admissible_class', 'Starting Class')
          newname.sub!('Completed_class', 'Finishing Class')
          node[:label] = newname[5..-2]
        end
      end.output(:svg => String)

    rescue => detail
      @logger.warn detail.message
      @logger.debug detail.backtrace.join "\n"
      return detail.message
    end

    svg
  end

end
