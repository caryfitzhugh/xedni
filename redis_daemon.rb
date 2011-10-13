require 'fileutils'

module Daemon
  WorkingDirectory = File.expand_path(File.dirname(__FILE__))

  class Base
    def self.pid_fn
      File.join(WorkingDirectory, "#{name}.pid")
    end

    def self.daemonize(cmd)
      Controller.daemonize(self, cmd)
    end
  end

  module PidFile
    def self.store(daemon, pid)
      File.open(daemon.pid_fn, 'w') {|f| f << pid}
    end

    def self.recall(daemon)
      IO.read(daemon.pid_fn).to_i rescue nil
    end
  end

  module Controller
    def self.daemonize(daemon, cmd)
      case cmd
      when 'start'
        start(daemon)
      when 'stop'
        stop(daemon)
      when 'restart'
        stop(daemon)
        start(daemon)
      else
        puts "Invalid command. Please specify start, stop or restart."
        exit
      end
    end

    def self.start(daemon)
      fork do
        Process.setsid
        exit if fork
        PidFile.store(daemon, Process.pid)
        Dir.chdir WorkingDirectory
        File.umask 0000
        STDIN.reopen "/dev/null"
        STDOUT.reopen "./redis_daemon.log", "a"
        STDERR.reopen STDOUT
        trap("TERM") {daemon.stop; exit}
        daemon.start
      end
    end

    def self.stop(daemon)
      if !File.file?(daemon.pid_fn)
        puts "Pid file not found. Is the daemon started?"
        return
      end
      pid = PidFile.recall(daemon)
      FileUtils.rm(daemon.pid_fn)
      pid && Process.kill("TERM", pid)
    end
  end
end

class RedisDaemon < Daemon::Base
  def self.start
    `bash #{File.join(File.expand_path(File.dirname(__FILE__)), 'start-redis.sh')}`
  end
  def self.stop
  end
end
