# vim: et sw=2

require 'open3'

module Xcodebuild
  def self.exec(xcodebuild_args, command, arguments = [])
    system('xcodebuild', *(xcodebuild_args + [command, *arguments]))
  end

  def self.platform_object_files_path(xcodebuild_args, target_name = nil)
    bs = build_settings(xcodebuild_args, target_name)
    variant = bs['CURRENT_VARIANT']
    dir = bs["OBJECT_FILE_DIR_#{variant}"] || bs['OBJECT_FILE_DIR']
    return nil if dir.nil?
    dir << '/' + bs['PLATFORM_PREFERRED_ARCH'].to_s
  end

  def self.build_settings(xcodebuild_args, target = nil)
    if target.nil?
      accum = XcodeFirstBuildableBuildSettingsAccumulator.new
    else
      accum = XcodeSpecificTargetBuildSettingsAccumulator.new target
    end

    Open3.popen3('xcodebuild', *(xcodebuild_args + [ '-showBuildSettings' ])) do |stdin, stdout, stderr|
      while stdout.gets
        accum.add_line $_.chomp
      end
    end

    accum.build_settings
  end

  private

  class XcodeFirstBuildableBuildSettingsAccumulator
    def initialize
      @have_armed = @armed = false
      @cliregexp = /^Build settings from command line:$/
      @regexp = /^Build settings for action build/
      @build_settings = { }
    end

    def add_line(line)
      line.chomp!

      if line.empty?
        @armed = false
      elsif @cliregexp.match line
        @armed = true
      elsif @have_armed
      elsif @regexp.match line
        @have_armed = @armed = true
      end

      return unless @armed

      /\s*(\w+)\s*=\s*(.*)/.match line do |m|
        k, v = m[1], m[2]
        @build_settings[k] = v
      end
    end

    attr_reader :build_settings
  end

  class XcodeSpecificTargetBuildSettingsAccumulator
    def initialize(target)
      @armed = false
      @cliregexp = /^Build settings from command line:$/
      @regexp = /^Build settings for action build and target #{Regexp.quote(target.to_s)}:$/
      @build_settings = { }
    end

    def add_line(line)
      line.chomp!

      if line.empty?
        @armed = false
      elsif @cliregexp.match line
        @armed = true
      elsif @regexp.match line
        @armed = true
      end

      return unless @armed

      /\s*(\w+)\s*=\s*(.*)/.match line do |m|
        k, v = m[1], m[2]
        @build_settings[k] = v
      end
    end

    attr_reader :build_settings
  end
end
