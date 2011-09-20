require 'goliath'
require 'tempfile'
require 'yaml'

class Stream < Goliath::API
  
  use Goliath::Rack::Params
  
  def response(env)
    api_token   = params[:api_token]
    revision    = params[:revision] || 'master'
    environment = params[:environment]
    app         = params[:app]
    
    return [ 422, {}, [ 'api_token, app, and environment parameters are required' ] ] unless api_token && environment && app
    
    tempfile = Tempfile.new('creds')
    tempfile.write({'api_token' => api_token}.to_yaml)
    tempfile.close
    
    ENV['EYRC'] = tempfile.path
    cmd = "ey deploy -a #{app} -e #{environment} -r #{revision}"
    
    # Set a timeout
    EM.add_timer(90) do
      env.stream_send("Command (#{cmd}) timed out\n")
      env.stream_close
    end
    
    # Run it
    EM.system(cmd) do |output,status|
      env.stream_send("#{output}\n")
      if status.exited?
        tempfile.unlink
        env.stream_close
      end
    end

    [200, {}, Goliath::Response::STREAMING]
  end
end

