require 'fileutils'

task :default do
  system("rake -T")
end

def version
  `git tag -l --sort=-v:refname 'v[0-9]*'`.each_line.first.chomp.sub('v','')
end

def next_version(type = :patch)
  section = [:major,:minor,:patch].index type

  n = version.split '.'
  n[section] = n[section].to_i + 1
  n.join '.'
end

desc "Build Docker image"
task 'docker' do
  Dir.chdir('build') do
    system("docker build --no-cache=true -t binford2k/puppet-validator:#{version} -t binford2k/puppet-validator:latest .")
  end
  puts
  puts 'Start container with: docker run -p 9000:9000 binford2k/puppet-validator'
end

desc "Upload image to Docker Hub"
task 'docker:push' => ['docker'] do
  system("docker push binford2k/puppet-validator:#{version}")
  system("docker push binford2k/puppet-validator:latest")
end

begin
  require 'mg'
  MG.new("puppet-validator.gemspec")
rescue LoadError
  puts "'gem install mg' to get helper gem publishing tasks. (optional)"
end

