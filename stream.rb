require 'goliath'
require 'tempfile'
require 'yaml'
require 'cgi'

class Stream < Goliath::API
  
  use Goliath::Rack::Params
  
  def response(env)
    api_token   = params[:api_token]
    revision    = params[:revision] || 'master'
    environment = params[:environment]
    app         = params[:app]
    key         = params[:key]
  
    return [ 422, {}, [ 'api_token, app, key, and environment parameters are required' ] ] unless api_token && environment && app && key
    
    creds_tempfile = Tempfile.new('creds')
    creds_tempfile.write({'api_token' => api_token}.to_yaml)
    creds_tempfile.close
    
    key_tempfile = Tempfile.new('key')
    key_tempfile.write(CGI.unescape(key))
    key_tempfile.close
    
    cmd = "ssh-agent sh -c 'ssh-add #{key_tempfile.path} < /dev/null && EYRC=#{creds_tempfile.path} ey deploy -a #{app} -e #{environment} -r #{revision}'"
    
    # Set a timeout
    EM.add_timer(90) do
      env.stream_send("Command (#{cmd}) timed out\n")
      env.stream_close
    end
    
    # Run it
    EM.system(cmd) do |output,status|
      env.stream_send("#{output}\n")
      if status.exited?
        creds_tempfile.unlink
        key_tempfile.unlink
        env.stream_close
      end
    end

    [200, {}, Goliath::Response::STREAMING]
  end
end

