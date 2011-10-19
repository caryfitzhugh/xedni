# Copyright (C) 2011 by Cary FitzHugh
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

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

      redis = Xedni::Connection.connection

      begin
        Xedni::Log.debug("Call: #{script_name} - #{json}")
        ActiveSupport::JSON.decode(redis.evalsha(script[:sha], 0, json))
      rescue
        ActiveSupport::JSON.decode(redis.eval(script[:content], 0, json))
      end
    end
  end
end
