#!/usr/bin/env ruby

module Ftpd
  class FtpServer < TlsServer

    extend Forwardable

    DEFAULT_SERVER_NAME = 'wconrad/ftpd'
    DEFAULT_SESSION_TIMEOUT = 300 # seconds

    # The number of seconds to delay before replying.  This is for
    # testing, when you need to test, for example, client timeouts.
    # Defaults to 0 (no delay).
    #
    # Set this before calling #start.

    attr_accessor :response_delay

    # The class for formatting for LIST output.  Defaults to
    # {Ftpd::ListFormat::Ls}.
    #
    # Set this before calling #start.

    attr_accessor :list_formatter

    # @return [Integer] The authentication level
    # One of:
    # * Ftpd::AUTH_USER
    # * Ftpd::AUTH_PASSWORD (default)
    # * Ftpd::AUTH_ACCOUNT

    attr_accessor :auth_level

    # The session timeout.  When a session is awaiting a command, if
    # one is not received in this many seconds, the session is
    # disconnected.  Defaults to {DEFAULT_SESSION_TIMEOUT}.  If nil,
    # then timeout is disabled.
    # @return [Numeric]
    #
    # Set this before calling #start.

    attr_accessor :session_timeout

    # The server's name, sent in a STAT reply.  Defaults to
    # {DEFAULT_SERVER_NAME}.
    #
    # Set this before calling #start.

    attr_accessor :server_name

    # The server's version, sent in a STAT reply.  Defaults to the
    # contents of the VERSION file.
    #
    # Set this before calling #start.

    attr_accessor :server_version

    # The logger.  Defaults to nil (no logging).
    # @return [Logger]
    #
    # Set this before calling #start.

    attr_accessor :log

    # Allow PORT command to specify data ports below 1024.  Defaults
    # to false.  Setting this to true makes it easier for an attacker
    # to use the server to attack another server.  See RFC 2577
    # section 3.
    # @return [Boolean]
    #
    # Set this before calling #start.

    attr_accessor :allow_low_data_ports

    # The maximum number of connections the server will allow, or nil
    # if there is no limit.
    # Defaults to {ConnectionThrottle::DEFAULT_MAX_CONNECTIONS}.
    # @return [Integer]
    #
    # Set this before calling #start.
    # @!attribute max_connections

    def_delegator :@connection_throttle, :'max_connections'
    def_delegator :@connection_throttle, :'max_connections='

    # Create a new FTP server.  The server won't start until the
    # #start method is called.
    #
    # @param driver A driver for the server's dynamic behavior such as
    #               authentication and file system access.
    #
    # The driver should expose these public methods:
    # * {Example::Driver#authenticate authenticate}
    # * {Example::Driver#file_system file_system}

    def initialize(driver)
      super()
      @driver = driver
      @response_delay = 0
      @list_formatter = ListFormat::Ls
      @auth_level = AUTH_PASSWORD
      @session_timeout = 300
      @server_name = DEFAULT_SERVER_NAME
      @server_version = read_version_file
      @allow_low_data_ports = false
      @log = nil
      @connection_tracker = ConnectionTracker.new
      @connection_throttle = ConnectionThrottle.new(@connection_tracker)
    end

    private

    def allow_session?(socket)
      @connection_throttle.allow?(socket)
    end

    def deny_session socket
      @connection_throttle.deny socket
    end

    def session(socket)
      @connection_tracker.track(socket) do
        run_session socket
      end
    end

    def run_session(socket)
      Session.new(:allow_low_data_ports => allow_low_data_ports,
                  :auth_level => @auth_level,
                  :driver => @driver,
                  :list_formatter => @list_formatter,
                  :log => log,
                  :response_delay => response_delay,
                  :server_name => @server_name,
                  :server_version => @server_version,
                  :session_timeout => @session_timeout,
                  :socket => socket,
                  :tls => @tls).run
    end

    def read_version_file
      File.open(version_file_path, 'r', &:read).strip
    end

    def version_file_path
      File.expand_path('../../VERSION', File.dirname(__FILE__))
    end

  end
end
