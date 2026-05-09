module ClipFileLoad
  module_function

  def load_test_num(source, test_number)
    text = source.is_a?(String) ? source : source.read
    blocks = split_caption_blocks(text)
    block = blocks[test_number - 1]
    return nil unless block

    h = {
      subjects: [],
      subjects_open: [],
      clip: [],
      sol_area: nil,
      sol_count: nil,
      clip_type: nil,
      fill_rule: nil
    }
    section = nil
    block.each_line do |raw|
      line = raw.strip
      next if line.empty?

      next if line =~ /\ACAPTION:/i

      if line =~ /\A([A-Z_]+):\s*(.*)\z/
        key = Regexp.last_match(1)
        val = Regexp.last_match(2).strip
        case key
        when "CLIPTYPE"
          h[:clip_type] = parse_clip_type(val)
        when "FILLRULE"
          h[:fill_rule] = parse_fill_rule(val)
        when "SOL_AREA"
          h[:sol_area] = val.to_i
        when "SOL_COUNT"
          h[:sol_count] = val.to_i
        end
        section = nil
        next
      end

      case line
      when "SUBJECTS"
        section = :subjects
      when "SUBJECTS_OPEN"
        section = :subjects_open
      when "CLIPS"
        section = :clip
      else
        next unless section

        path = parse_path_line(line)
        h[section] << path unless path.empty?
      end
    end
    h
  end

  def split_caption_blocks(text)
    parts = text.split(/(?=^CAPTION:\s*\d+)/m)
    parts.map(&:strip).reject(&:empty?)
  end

  def parse_path_line(line)
    line.scan(/-?\d+\s*,\s*-?\d+/).map do |pair|
      x, y = pair.split(",").map(&:strip).map(&:to_i)
      Clipper2.point64(x, y)
    end
  end

  def parse_clip_type(s)
    case s.upcase
    when "INTERSECTION" then Clipper2::INTERSECTION
    when "UNION" then Clipper2::UNION
    when "DIFFERENCE" then Clipper2::DIFFERENCE
    when "XOR" then Clipper2::XOR
    when "NO_CLIP" then Clipper2::NO_CLIP
    when "OFFSET" then :offset
    else
      raise ArgumentError, s
    end
  end

  def parse_fill_rule(s)
    case s.upcase
    when "EVENODD" then Clipper2::EVEN_ODD
    when "NONZERO" then Clipper2::NON_ZERO
    when "POSITIVE" then Clipper2::POSITIVE
    when "NEGATIVE" then Clipper2::NEGATIVE
    else
      raise ArgumentError, s
    end
  end
end
