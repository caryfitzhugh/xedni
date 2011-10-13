require 'digest/sha1'

module Xedni
  module Scripts
    def self.scripts
      @@scripts ||= {}
    end
    SCRIPTS     = {}
    COMMON_LUA = File.read(File.join(File.dirname(__FILE__), 'common.lua'))

    Dir[File.join(File.dirname(__FILE__),"scripts","*.lua")].collect do |file|
      content = File.read(file)
      content = COMMON_LUA + content

      sha = Digest::SHA1.hexdigest content
      SCRIPTS[File.basename(file).split('.').first.to_sym] = {:sha=>sha, :content=>content, :file=>file}
    end

    def self.method_missing(*args)
      script_name =  args.shift.to_s
      arguments = args.first
      script = SCRIPTS[script_name.to_sym]
      json = ActiveSupport::JSON.encode arguments

      if script.blank?
        raise "INVALID Redis Script: #{script_name}"
      end

      begin
        Xedni::Log.debug("Call: #{script_name} - #{json}")
        ActiveSupport::JSON.decode($redis.evalsha(script[:sha], 0, json))
      rescue Exception => e
        if (e.to_s =~ /^NOSCRIPT/)
          ActiveSupport::JSON.decode($redis.eval(script[:content], 0, json))
        else
          raise e
        end
      end
    end
  end
end
