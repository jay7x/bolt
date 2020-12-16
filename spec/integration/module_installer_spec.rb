# frozen_string_literal: true

require 'bolt_spec/integration'
require 'bolt_spec/project'

describe 'installing modules' do
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:command) { %w[module install] }
  let(:project) { @project }

  around(:each) do |example|
    with_project(config: project_config) do |project|
      @project = project
      example.run
    end
  end

  # Suppress output
  before(:each) do
    allow($stderr).to receive(:puts)
  end

  context 'with install configuration' do
    let(:base_config) do
      {
        'module-install' => {
          'forge' => {
            'baseurl' => 'https://forge.example.com',
            'proxy'   => 'https://myforgeproxy.example.com'
          },
          'proxy' => 'https://myproxy.example.com'
        }
      }
    end

    context 'with Forge modules' do
      let(:project_config) { base_config.merge('modules' => ['puppetlabs-yaml']) }

      it 'uses the forge configuration' do
        expect { run_cli(command, project: project) }.to raise_error(
          Bolt::Error,
          %r{on https://forge.example.com with proxy https://myforgeproxy.example.com}
        )
      end
    end

    context 'with git modules' do
      let(:project_config) do
        base_config.merge(
          'modules' => [
            {
              'git' => 'https://github.com/puppetlabs/puppetlabs-yaml',
              'ref' => '0.1.0'
            }
          ]
        )
      end

      it 'uses the global proxy' do
        expect { run_cli(command, project: project) }.to raise_error(
          Bolt::Error,
          %r{with proxy https://myproxy.example.com}
        )
      end
    end
  end

  context 'with forge and git modules' do
    let(:project_config) do
      {
        'modules' => [
          {
            'name'                => 'puppetlabs/yaml',
            'version_requirement' => '0.1.0'
          },
          {
            'git' => 'https://github.com/puppetlabs/puppetlabs-ruby_task_helper',
            'ref' => '0.4.0'
          }
        ]
      }
    end

    it 'resolves and installs modules' do
      result = run_cli(command, project: project)

      expect(JSON.parse(result)).to eq(
        'success'    => true,
        'puppetfile' => project.puppetfile.to_s,
        'moduledir'  => project.managed_moduledir.to_s
      )
      expect(project.puppetfile.exist?).to be(true)
      expect(project.managed_moduledir.exist?).to be(true)

      puppetfile_content = File.read(project.puppetfile)

      expect(puppetfile_content.lines).to include(
        /mod 'ruby_task_helper'/,
        %r{git: 'https://github.com/puppetlabs/puppetlabs-ruby_task_helper'},
        /ref: '23520d05ef8e3f9e1327804bc7d2e1bba33d1df9'/,
        %r{mod 'puppetlabs/yaml', '0.1.0'}
      )
    end
  end

  context 'with unresolvable modules' do
    let(:project_config) do
      {
        'modules' => [
          {
            'name'                => 'puppetlabs/yaml',
            'version_requirement' => '0.1.0'
          },
          {
            'git' => 'https://github.com/puppetlabs/puppetlabs-ruby_task_helper',
            'ref' => '0.3.0'
          }
        ]
      }
    end

    it 'errors' do
      expect { run_cli(command, project: project) }.to raise_error(
        Bolt::Error,
        /could not find compatible versions for possibility named "ruby_task_helper"/
      )
    end
  end

  context 'with unknown git modules' do
    let(:project_config) do
      {
        'modules' => [
          {
            'name'                => 'puppetlabs/yaml',
            'version_requirement' => '0.1.0'
          },
          {
            'git' => 'https://github.com/puppetlabs/puppetlabs-foobarbaz',
            'ref' => '0.1.0'
          }
        ]
      }
    end

    it 'errors' do
      expect { run_cli(command, project: project) }.to raise_error(
        Bolt::Error,
        %r{https://github.com/puppetlabs/puppetlabs-foobarbaz is not a git repository.}
      )
    end
  end
end
