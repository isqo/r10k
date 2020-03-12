require 'spec_helper'

require 'r10k/logging'
require 'r10k/action/deploy/deploy_helpers'

describe R10K::Action::Deploy::DeployHelpers do
  subject do
    Object.new.tap do |o|
      o.extend(R10K::Logging)
      o.extend(described_class)
    end
  end

  describe "checking for a config file" do
    it "logs a warning and exits when no config file was set" do
      logger = subject.logger

      expect(logger).to receive(:fatal).with("No configuration file given, no config file found in current directory, and no global config present")

      expect {
        subject.expect_config!
      }.to exit_with(8)
    end
  end

  describe "checking the write lock setting" do
    it "logs a warning and exits when the write lock is set" do
      logger = subject.logger

      expect(logger).to receive(:fatal).with("Making changes to deployed environments has been administratively disabled.")
      expect(logger).to receive(:fatal).with("Reason: r10k is sleepy and wants to take a nap")

      expect {
        subject.check_write_lock!(deploy: {write_lock: "r10k is sleepy and wants to take a nap"})
      }.to exit_with(16)
    end
  end


  describe "write_environment_info!" do

    class Fake_Environment
      attr_accessor :path
      attr_accessor :puppetfile
      attr_accessor :info

      def initialize(path, info)
        @path = path
        @info = info
        @puppetfile = R10K::Puppetfile.new
      end
    end

    let(:mock_stateful_repo_1) { instance_double("R10K::Git::StatefulRepository", :head => "123456") }
    let(:mock_stateful_repo_2) { instance_double("R10K::Git::StatefulRepository", :head => "654321") }
    let(:mock_git_module_1) { instance_double("R10K::Module::Git", :name => "my_cool_module", :version => "1.0", :repo => mock_stateful_repo_1) }
    let(:mock_git_module_2) { instance_double("R10K::Module::Git", :name => "my_lame_module", :version => "0.0.1", :repo => mock_stateful_repo_2) }
    let(:mock_forge_module_1) { double(:name => "their_shiny_module", :version => "2.0.0") }
    let(:mock_puppetfile) { instance_double("R10K::Puppetfile", :modules => [mock_git_module_1, mock_git_module_2, mock_forge_module_1]) }

    before(:all) do
      @tmp_path = "./tmp-r10k-test-dir/"
      Dir.mkdir(@tmp_path) unless File.exists?(@tmp_path)
    end

    after(:all) do
      File.delete("#{@tmp_path}/.r10k-deploy.json")
      Dir.delete(@tmp_path)
    end

    it "writes the .r10k-deploy file correctly" do
      allow(R10K::Puppetfile).to receive(:new).and_return(mock_puppetfile)
      allow(mock_forge_module_1).to receive(:repo).and_raise(NoMethodError)

      fake_env = Fake_Environment.new(@tmp_path, {:name => "my_cool_environment", :signature => "pablo picasso"})
      allow(fake_env).to receive(:modules).and_return(mock_puppetfile.modules)
      subject.send(:write_environment_info!, fake_env, "2019-01-01 23:23:22 +0000", true)

      file_contents = File.read("#{@tmp_path}/.r10k-deploy.json")
      r10k_deploy = JSON.parse(file_contents)

      expect(r10k_deploy['name']).to eq("my_cool_environment")
      expect(r10k_deploy['signature']).to eq("pablo picasso")
      expect(r10k_deploy['started_at']).to eq("2019-01-01 23:23:22 +0000")
      expect(r10k_deploy['deploy_success']).to eq(true)
      expect(r10k_deploy['module_deploys'].length).to eq(3)
      expect(r10k_deploy['module_deploys'][0]['name']).to eq("my_cool_module")
      expect(r10k_deploy['module_deploys'][0]['version']).to eq("1.0")
      expect(r10k_deploy['module_deploys'][0]['sha']).to eq("123456")
      expect(r10k_deploy['module_deploys'][1]['name']).to eq("my_lame_module")
      expect(r10k_deploy['module_deploys'][1]['version']).to eq("0.0.1")
      expect(r10k_deploy['module_deploys'][1]['sha']).to eq("654321")
      expect(r10k_deploy['module_deploys'][2]['name']).to eq("their_shiny_module")
      expect(r10k_deploy['module_deploys'][2]['version']).to eq("2.0.0")
      expect(r10k_deploy['module_deploys'][2]['sha']).to eq(nil)

    end
  end
end
