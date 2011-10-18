module Xedni::Log
  def self.debug(*args)
    if ENV['XEDNI_LOGGING']
      Logger.new(STDOUT).debug("Xedni") { args.join("\n") }
    end
  end
end
