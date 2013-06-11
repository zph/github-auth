module Github::Auth
  # Write and delete keys from the authorized_keys file
  class KeysFile
    attr_reader :path

    PermissionDeniedError = Class.new StandardError
    FileDoesNotExistError = Class.new StandardError

    DEFAULT_PATH = '~/.ssh/authorized_keys'

    def initialize(options = {})
      default  = is_root? ? nil : DEFAULT_PATH
      @path = File.expand_path(options[:path] || default)
      # exit(1) if is_root?
    end

    def write!(keys)
      Array(keys).each do |key|
        unless keys_file_content.include? key.key
          append_keys_file do |keys_file|
            keys_file.write "\n" unless keys_file_content.empty?
            keys_file.write key
          end
        end
      end
    end

    def is_root?
      Process.euid
    end

    def delete!(keys)
      new_content = keys_file_content_without keys

      write_keys_file { |keys_file| keys_file.write new_content }
    end

    private

    def append_keys_file(&block)
      with_keys_file 'a', block
    end

    def write_keys_file(&block)
      with_keys_file 'w', block
    end

    def keys_file_content
      with_keys_file 'r', Proc.new { |keys_file| keys_file.read }
    end

    def with_keys_file(mode, block)
      File.open(path, mode) { |keys_file| block.call keys_file }
    rescue Errno::EACCES => e
      raise PermissionDeniedError, e
    rescue Errno::ENOENT => e
      raise FileDoesNotExistError, e
    end

    def keys_file_content_without(keys)
      keys_file_content.tap do |content|
        Array(keys).each do |key|
          content.gsub! /#{Regexp.escape key.key}( .*)?$\n?/, ''
        end

        content.strip!
      end
    end
  end
end
