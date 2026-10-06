module GlTail
  module Source

    # Reads log lines from standard input, so the output of any command can be
    # piped into glTail, logstalgia-style:
    #
    #   ssh me@server docker logs --follow --tail 1 web | gl_tail --stdin
    #
    # Reading is non-blocking and happens on the render loop's timer, so a
    # quiet pipe never freezes the window. When the pipe closes, the window
    # stays open with whatever has been seen so far.
    class Stdin < Base
      config_attribute :source, 'The type of Source'
      config_attribute :host, 'Host name of the logged site (used to ignore self-referrals)'

      # Upper bound per frame, so a burst of backlog can't stall rendering.
      MAX_BYTES_PER_FRAME = 256 * 1024

      def init
        @io = $stdin
        @buffer = String.new
        @eof = false

        if @io.tty?
          puts 'Waiting for log lines on stdin. Pipe a command into gl_tail, e.g.:',
               '  ssh me@server tail -f /var/log/apache2/access.log | gl_tail --stdin'
        end
      end

      def process
        return if @eof

        read = 0
        while read < MAX_BYTES_PER_FRAME
          chunk = @io.read_nonblock(65536, exception: false)

          case chunk
          when :wait_readable
            break
          when nil
            @eof = true
            parse_line(@buffer) unless @buffer.empty?
            @buffer = String.new
            puts 'stdin closed; no more log lines will arrive.' if $VRB > 0
            break
          else
            read += chunk.bytesize
            @buffer << chunk
            # Only hand complete lines to the parser; keep a trailing partial
            # line in the buffer until the rest of it arrives.
            while (i = @buffer.index("\n"))
              parse_line(@buffer.slice!(0, i + 1))
            end
          end
        end
      rescue IOError, Errno::EBADF
        @eof = true
      end

      def update
      end

      private

      def parse_line(raw)
        line = raw.chomp.force_encoding(Encoding::UTF_8).scrub
        return if line.empty?

        puts "stdin: #{line}" if $DBG > 0
        parser.parse(line)
      end
    end
  end
end
