require 'goliath'
require 'tempfile'
require 'yaml'

class Stream < Goliath::API
  
  get '/deploy' do
    api_key = params[:api_key]
    revision = params[:revision] || 'master'
    environment = params[:environment]
    tempfile = Tempfile.new('creds')
    tempfile.write({:api_key => api_key}.to_yaml)
    tempfile.close
    
    cmd = "EYRC=#{tempfile.path} ey deploy -e #{environment} -r #{revision}"
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

