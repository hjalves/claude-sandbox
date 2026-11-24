# Work around a false "port in use" result in Vagrant's forwarded-port check.
#
# Vagrant 2.4.9 ships Ruby 3.3.8, whose Socket.tcp(host, port, connect_timeout:)
# reports a *refused* connection as connected on this macOS. Vagrant then
# believes every port in 2200..2250 is taken, falls back to the last one (2250)
# for every machine, and the second VM that runs fails with QEMU's "Could not
# set up host forwarding rule". Load this from a Vagrantfile to replace the
# check with one that honours the connection result.

require "socket"
require "timeout"
require "vagrant/util/is_port_open"

module Vagrant
  module Util
    module IsPortOpen
      def is_port_open?(host, port)
        Timeout.timeout(1) { Socket.tcp(host, port).close }
        true
      rescue Timeout::Error, SystemCallError, SocketError
        false
      end
    end
  end
end
