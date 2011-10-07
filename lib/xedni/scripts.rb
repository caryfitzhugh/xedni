require 'digest/sha1'

module Xedni::Scripts
  def self.scripts
    @@scripts ||= {}
  end
  SCRIPTS     = {}
  COMMON_LUA = File.read(File.join(File.dirname(__FILE__), 'common.lua'))

  Dir[File.join(File.dirname(__FILE__),"scripts","*")].collect do |file|
    content = File.read(file)
    content = COMMON_LUA + content

    sha = Digest::SHA1.hexdigest content
    SCRIPTS[File.basename(file).to_sym] = {:sha=>sha, :content=>content, :file=>file}
  end

  def self.method_missing(*args)
    script =  args.shift.to_s
    arguments = args
    script = SCRIPTS[script.to_sym]

    if script.blank?
      raise "INVALID Redis Script: #{script}"
    end

    begin
      $redis.evalsha(script[:sha],0, *arguments)
    rescue Exception => e
      if (e.to_s =~ /^NOSCRIPT/)
        $redis.eval(script[:content], 0, *arguments)
      else
        raise e
      end
    end
  end
end
