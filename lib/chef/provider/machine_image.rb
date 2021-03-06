require 'chef/provider/lwrp_base'
require 'chef/provider/chef_node'
require 'openssl'
require 'chef/provisioning/chef_provider_action_handler'
require 'chef/provisioning/chef_image_spec'

class Chef
class Provider
class MachineImage < Chef::Provider::LWRPBase

  def action_handler
    @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
  end

  def load_current_resource
  end

  # Get the driver specified in the resource
  def new_driver
    @new_driver ||= run_context.chef_provisioning.driver_for(new_resource.driver)
  end

  action :create do
    # Get the image mapping on the server (from name to image-id)
    image_spec = Chef::Provisioning::ChefImageSpec.get(new_resource.name, new_resource.chef_server) ||
                 Chef::Provisioning::ChefImageSpec.empty(new_resource.name, new_resource.chef_server)
    if image_spec.location
      # TODO check for real existence and maybe update
    else
      #
      # Create a new image
      #
      image_spec.machine_options = new_resource.machine_options
      create_image(image_spec)
    end
  end

  action :destroy do
  end

  def create_image(image_spec)
    # 1. Create the exemplar machine
    machine_provider = Chef::Provider::Machine.new(new_resource, run_context)
    machine_provider.load_current_resource
    machine_provider.action_converge

    # 2. Create the image
    new_driver.allocate_image(action_handler, image_spec, new_resource.image_options,
                              machine_provider.machine_spec)

    # 3. Save the linkage from name -> image id
    image_spec.save(action_handler)

    # 4. Wait for image to be ready
    new_driver.ready_image(action_handler, image_spec, new_resource.image_options)
  end

end
end
end