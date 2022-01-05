source 'https://rubygems.org/' do
  group :test do
    gem 'kitchen-terraform', "~> 6.0"
  end
end

source 'https://packagecloud.io/cinc-project/stable' do
  group :test do
    gem 'cinc-auditor-bin', '~> 4.52'
    # Follows are dependencies of both kitchen-tf and cinc-auditor. We explicitly use Cinc versions of these gems
    # to avoid any trademark infringment issues. They are functionally identical to their upstream counterparts.
    gem 'chef-utils'
    gem 'chef-config'
    gem 'inspec'
    gem 'inspec-core'
  end
end
