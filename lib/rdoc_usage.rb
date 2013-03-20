# Adapter for what we need to remove dependency on RDoc which was removed in ruby 1.9
class RdocUsage

  def RdocUsage.message
    path = Library.normalize_path(RdocUsage.program_name)

    lines = []
    lines << ""
    lines << "USAGE: #{path}"
    lines << ""

    IO.readlines(path).each do |line|
      if !line.match(/^\#/)
        break
      end
      if line.match(/^\#\!/)
        next
      end
      lines << line.sub(/^\#+/, '').strip
    end
    lines << ""

    lines.join("\n")
  end

  def RdocUsage.printAndExit(exit_code=0)
    puts RdocUsage.message
    exit(exit_code)
  end

  private
  def RdocUsage.program_name
    $0
  end


end
