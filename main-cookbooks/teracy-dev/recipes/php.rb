#
# Author:: Hoat Le <hoatlevan@gmail.com>
# Cookbook Name:: dev
# Recipe:: php
#
# Copyright 2014, Teracy, Inc.
#

if node['teracy-dev']['php']['enabled']
  if !node['teracy-dev']['php']['version'].strip().empty?
      package 'apache2-dev' do
        action :install
      end

      bash 'remove php version if need' do
        code <<-EOF
          php_binary=$(which php);
          php_version=$(php -r '@phpinfo();' | grep 'PHP Version' -m 1 | awk '{print $4}');

          if [ "$php_version" != "#{node['teracy-dev']['php']['version']}" ] || [ ! -f /usr/lib/apache2/modules/mod_php5.so ]; then
              rm -R `ls -1 -d /var/chef/cache/php*/`
              apt-get remove php5* -f || true
              rm $php_binary -rf || true
              rm /usr/lib/apache2/modules/libphp5.so -rf || true
              rm /usr/lib/apache2/modules/mod_php5.so -rf || true
          fi
        EOF
        only_if 'which php'
        user 'root'
      end
      node.override['php']['version'] = node['teracy-dev']['php']['version']
      node.override['php']['checksum'] = node['teracy-dev']['php']['checksum']
      node.override['php']['install_method'] = 'source'
      node.override['php']['configure_options'] = ['--with-apxs2=/usr/bin/apxs2'] + node['php']['configure_options']

     	include_recipe 'php'
      bash 'update apache2 php modules to source' do
        code <<-EOF
          mv /usr/lib/apache2/modules/libphp5.so /usr/lib/apache2/modules/mod_php5.so
          echo 'LoadModule php5_module        /usr/lib/apache2/modules/mod_php5.so' > /etc/apache2/mods-available/php5.load
        EOF
        only_if 'ls -la /usr/lib/apache2/modules/libphp5.so'
        user 'root'
      end
  else
    	include_recipe 'php'
      if  node['teracy-dev']['mysql']['enabled']
     		include_recipe 'php::module_mysql'
     	end
  end

  bash 'clean up apache mess' do
      code <<-EOF
          a2enmod php5 || true;
          service apache2 restart;
      EOF
      user 'root'
  end

  if node['teracy-dev']['php']['phpmyadmin']['enabled']

      phpmyadmin_user = node['teracy-dev']['php']['phpmyadmin']['user']
      phpmyadmin_group = node['teracy-dev']['php']['phpmyadmin']['group']
      phpmyadmin_version = node['teracy-dev']['php']['phpmyadmin']['version']
      phpmyadmin_checksum = node['teracy-dev']['php']['phpmyadmin']['checksum']
      phpmyadmin_mirror = node['teracy-dev']['php']['phpmyadmin']['mirror']

      node.override['phpmyadmin']['fpm'] = node['teracy-dev']['php']['phpmyadmin']['fpm']
      
      

      if !phpmyadmin_version.nil? and !phpmyadmin_version.strip().empty?
          node.override['phpmyadmin']['version'] = phpmyadmin_version
      end

      if !phpmyadmin_checksum.nil? and !phpmyadmin_checksum.strip().empty?
          node.override['phpmyadmin']['checksum'] = phpmyadmin_checksum
      end

      if !phpmyadmin_mirror.nil? and !phpmyadmin_mirror.strip().empty?
          node.override['phpmyadmin']['mirror'] = phpmyadmin_mirror
      end

      include_recipe 'phpmyadmin::default'

      phpmyadmin_db 'Test DB' do
        host '0.0.0.0'
        username 'root'
        password 'teracy'
      end

  end

end
