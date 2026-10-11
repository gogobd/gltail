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

      # Time per frame for parsing log lines, so a burst can't stall a frame;
      # lines left over wait in the buffer for the next frame.
      PARSE_BUDGET = 0.004 # seconds
      # Stop reading from the pipe while this much is still waiting (the
      # sender then waits too, instead of glTail buffering without limit).
      MAX_BACKLOG  = 4 * 1024 * 1024

      def init
        @io = $stdin
        @buffer = String.new(encoding: Encoding::BINARY)
        @pos = 0
        @eof = false

        if @io.tty?
          puts 'Waiting for log lines on stdin. Pipe a command into gl_tail, e.g.:',
               '  ssh me@server tail -f /var/log/apache2/access.log | gl_tail --stdin'
        end
      end

      def process
        return if @eof && @buffer.empty?

        deadline = now + PARSE_BUDGET
        loop do
          # Parse complete lines already buffered; keep a trailing partial
          # line until the rest of it arrives.
          while (i = @buffer.byteindex("\n", @pos))
            parse_line(@buffer.byteslice(@pos, i + 1 - @pos))
            @pos = i + 1
            return compact_buffer if now >= deadline
          end
          compact_buffer

          break if @eof || @buffer.bytesize >= MAX_BACKLOG

          chunk = @io.read_nonblock(65536, exception: false)
          case chunk
          when :wait_readable
            break
          when nil
            @eof = true
            parse_line(@buffer) unless @buffer.empty?
            @buffer = String.new(encoding: Encoding::BINARY)
            puts 'stdin closed; no more log lines will arrive.' if $VRB > 0
            break
          else
            @buffer << chunk
          end
        end
      rescue IOError, Errno::EBADF
        @eof = true
      end

      def update
      end

      private

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def compact_buffer
        return if @pos == 0
        @buffer = @buffer.byteslice(@pos, @buffer.bytesize - @pos)
        @pos = 0
      end

      def parse_line(raw)
        line = raw.dup.force_encoding(Encoding::UTF_8).chomp.scrub
        return if line.empty?

        puts "stdin: #{line}" if $DBG > 0
        parser.parse(line)
      end
    end
  end
end
