require_relative "core"

module Clipper2
  LOCATION_LEFT = 0
  LOCATION_TOP = 1
  LOCATION_RIGHT = 2
  LOCATION_BOTTOM = 3
  LOCATION_INSIDE = 4

  class RectClipOutPt2
    attr_accessor :pt, :owner_idx, :edge, :op_next, :op_prev

    def initialize
      @owner_idx = 0
      @edge = nil
      @op_next = nil
      @op_prev = nil
    end
  end

  module RectClipGeom
    module_function

    def path1_contains_path2(path1, path2)
      io_count = 0
      path2.each do |pt|
        case Clipper2.point_in_polygon_result(pt, path1)
        when POINT_IN_POLYGON_IS_OUTSIDE
          io_count += 1
        when POINT_IN_POLYGON_IS_INSIDE
          io_count -= 1
        else
          next
        end
        break if io_count.abs > 1
      end
      io_count <= 0
    end

    def get_location(rec, pt)
      loc = [0]
      [get_location_inner(rec, pt, loc), loc[0]]
    end

    def get_location_inner(rec, pt, loc_box)
      loc = loc_box
      if pt.x == rec.left && pt.y >= rec.top && pt.y <= rec.bottom
        loc[0] = LOCATION_LEFT
        return false
      elsif pt.x == rec.right && pt.y >= rec.top && pt.y <= rec.bottom
        loc[0] = LOCATION_RIGHT
        return false
      elsif pt.y == rec.top && pt.x >= rec.left && pt.x <= rec.right
        loc[0] = LOCATION_TOP
        return false
      elsif pt.y == rec.bottom && pt.x >= rec.left && pt.x <= rec.right
        loc[0] = LOCATION_BOTTOM
        return false
      elsif pt.x < rec.left
        loc[0] = LOCATION_LEFT
      elsif pt.x > rec.right
        loc[0] = LOCATION_RIGHT
      elsif pt.y < rec.top
        loc[0] = LOCATION_TOP
      elsif pt.y > rec.bottom
        loc[0] = LOCATION_BOTTOM
      else
        loc[0] = LOCATION_INSIDE
      end
      true
    end

    def horizontal_segment?(pt1, pt2)
      pt1.y == pt2.y
    end

    def get_segment_intersection(p1, p2, p3, p4)
      res1 = Clipper2.cross_product_sign(p1, p3, p4)
      res2 = Clipper2.cross_product_sign(p2, p3, p4)
      if res1 == 0
        ip = p1.dup
        if res2 == 0
          return [false, ip]
        elsif p1 == p3 || p1 == p4
          return [true, ip]
        elsif horizontal_segment?(p3, p4)
          return [true, ip] if (p1.x > p3.x) == (p1.x < p4.x)
          return [false, ip]
        else
          return [true, ip] if (p1.y > p3.y) == (p1.y < p4.y)
          return [false, ip]
        end
      elsif res2 == 0
        ip = p2.dup
        if p2 == p3 || p2 == p4
          return [true, ip]
        elsif horizontal_segment?(p3, p4)
          return [true, ip] if (p2.x > p3.x) == (p2.x < p4.x)
          return [false, ip]
        else
          return [true, ip] if (p2.y > p3.y) == (p2.y < p4.y)
          return [false, ip]
        end
      end
      return [false, nil] if (res1 > 0) == (res2 > 0)
      res3 = Clipper2.cross_product_sign(p3, p1, p2)
      res4 = Clipper2.cross_product_sign(p4, p1, p2)
      if res3 == 0
        ip = p3.dup
        if p3 == p1 || p3 == p2
          return [true, ip]
        elsif horizontal_segment?(p1, p2)
          return [true, ip] if (p3.x > p1.x) == (p3.x < p2.x)
          return [false, ip]
        else
          return [true, ip] if (p3.y > p1.y) == (p3.y < p2.y)
          return [false, ip]
        end
      elsif res4 == 0
        ip = p4.dup
        if p4 == p1 || p4 == p2
          return [true, ip]
        elsif horizontal_segment?(p1, p2)
          return [true, ip] if (p4.x > p1.x) == (p4.x < p2.x)
          return [false, ip]
        else
          return [true, ip] if (p4.y > p1.y) == (p4.y < p2.y)
          return [false, ip]
        end
      end
      return [false, nil] if (res3 > 0) == (res4 > 0)
      ok, ip = Clipper2.get_line_intersect_pt(p1, p2, p3, p4)
      return [false, nil] unless ok
      [true, ip]
    end

    def get_intersection(rect_path, p, p2, loc_box)
      loc = loc_box[0]
      ip = nil
      case loc
      when LOCATION_LEFT
        ok, ip = get_segment_intersection(p, p2, rect_path[0], rect_path[3])
        return [true, ip] if ok
        if p.y < rect_path[0].y
          ok, ip = get_segment_intersection(p, p2, rect_path[0], rect_path[1])
          if ok
            loc_box[0] = LOCATION_TOP
            return [true, ip]
          end
        end
        ok, ip = get_segment_intersection(p, p2, rect_path[2], rect_path[3])
        return [true, ip] if ok
        return [false, nil]
      when LOCATION_TOP
        ok, ip = get_segment_intersection(p, p2, rect_path[0], rect_path[1])
        return [true, ip] if ok
        if p.x < rect_path[0].x
          ok, ip = get_segment_intersection(p, p2, rect_path[0], rect_path[3])
          if ok
            loc_box[0] = LOCATION_LEFT
            return [true, ip]
          end
        end
        ok, ip = get_segment_intersection(p, p2, rect_path[1], rect_path[2])
        return [true, ip] if ok
        return [false, nil]
      when LOCATION_RIGHT
        ok, ip = get_segment_intersection(p, p2, rect_path[1], rect_path[2])
        return [true, ip] if ok
        if p.y < rect_path[1].y
          ok, ip = get_segment_intersection(p, p2, rect_path[0], rect_path[1])
          if ok
            loc_box[0] = LOCATION_TOP
            return [true, ip]
          end
        end
        ok, ip = get_segment_intersection(p, p2, rect_path[2], rect_path[3])
        return [true, ip] if ok
        return [false, nil]
      when LOCATION_BOTTOM
        ok, ip = get_segment_intersection(p, p2, rect_path[2], rect_path[3])
        return [true, ip] if ok
        if p.x < rect_path[3].x
          ok, ip = get_segment_intersection(p, p2, rect_path[0], rect_path[3])
          if ok
            loc_box[0] = LOCATION_LEFT
            return [true, ip]
          end
        end
        ok, ip = get_segment_intersection(p, p2, rect_path[1], rect_path[2])
        return [true, ip] if ok
        return [false, nil]
      else
        ok, ip = get_segment_intersection(p, p2, rect_path[0], rect_path[3])
        if ok
          loc_box[0] = LOCATION_LEFT
          return [true, ip]
        end
        ok, ip = get_segment_intersection(p, p2, rect_path[0], rect_path[1])
        if ok
          loc_box[0] = LOCATION_TOP
          return [true, ip]
        end
        ok, ip = get_segment_intersection(p, p2, rect_path[1], rect_path[2])
        if ok
          loc_box[0] = LOCATION_RIGHT
          return [true, ip]
        end
        ok, ip = get_segment_intersection(p, p2, rect_path[2], rect_path[3])
        if ok
          loc_box[0] = LOCATION_BOTTOM
          return [true, ip]
        end
        return [false, nil]
      end
    end

    def get_adjacent_location(loc, is_clockwise)
      delta = is_clockwise ? 1 : 3
      (loc + delta) % 4
    end

    def heading_clockwise?(prev, curr)
      ((prev + 1) % 4) == curr
    end

    def are_opposites?(prev, curr)
      (prev - curr).abs == 2
    end

    def is_clockwise_corner?(prev, curr, prev_pt, curr_pt, rect_mp)
      if are_opposites?(prev, curr)
        Clipper2.cross_product_sign(prev_pt, rect_mp, curr_pt) < 0
      else
        heading_clockwise?(prev, curr)
      end
    end

    def start_locs_are_clockwise?(start_locs)
      result = 0
      (1...start_locs.length).each do |i|
        d = start_locs[i] - start_locs[i - 1]
        case d
        when -1 then result -= 1
        when 1 then result += 1
        when -3 then result += 1
        when 3 then result -= 1
        end
      end
      result > 0
    end

    def get_edges_for_pt(pt, rec)
      result = 0
      result = 1 if pt.x == rec.left
      result = 4 if pt.x == rec.right
      if pt.y == rec.top
        result += 2
      elsif pt.y == rec.bottom
        result += 8
      end
      result
    end

    def heading_clockwise_edge?(pt1, pt2, edge_idx)
      case edge_idx
      when 0 then pt2.y < pt1.y
      when 1 then pt2.x > pt1.x
      when 2 then pt2.y > pt1.y
      else pt2.x < pt1.x
      end
    end

    def has_horz_overlap(left1, right1, left2, right2)
      left1.x < right2.x && right1.x > left2.x
    end

    def has_vert_overlap(top1, bottom1, top2, bottom2)
      top1.y < bottom2.y && bottom1.y > top2.y
    end

    def add_to_edge(edge, op)
      return if op.edge
      op.edge = edge
      edge << op
    end

    def uncouple_edge(op)
      return unless op.edge
      op.edge.each_with_index do |op2, i|
        next unless op2 == op
        op.edge[i] = nil
        break
      end
      op.edge = nil
    end

    def set_new_owner(op, new_idx)
      op.owner_idx = new_idx
      op2 = op.op_next
      while op2 != op
        op2.owner_idx = new_idx
        op2 = op2.op_next
      end
    end

    def unlink_op(op)
      return nil if op.op_next == op
      op.op_prev.op_next = op.op_next
      op.op_next.op_prev = op.op_prev
      op.op_next
    end

    def unlink_op_back(op)
      return nil if op.op_next == op
      op.op_prev.op_next = op.op_next
      op.op_next.op_prev = op.op_prev
      op.op_prev
    end
  end

  class RectClip64
    include RectClipGeom

    attr_reader :rect, :rect_as_path, :rect_mp

    def initialize(rect)
      @rect = rect
      @rect_as_path = rect.as_path
      @rect_mp = rect.midpoint
      @path_bounds = nil
      @op_container = []
      @results = []
      @edges = Array.new(8) { [] }
      @start_locs = []
    end

    def execute(paths)
      result = []
      return result if @rect.is_empty?
      paths.each do |path|
        next if path.size < 3
        @path_bounds = Clipper2.get_bounds_path(path)
        next unless @rect.intersects?(@path_bounds)
        if @rect.contains_rect?(@path_bounds)
          result << path.map(&:dup)
          next
        end
        execute_internal(path)
        check_edges
        4.times do |i|
          tidy_edges(i, @edges[i * 2], @edges[i * 2 + 1])
        end
        @results.each do |op|
          next unless op
          tmp = get_path(op)
          result << tmp unless tmp.empty?
        end
        @op_container.clear
        @results.clear
        @edges.each(&:clear)
        @start_locs.clear
      end
      result
    end

    protected

    def add(pt, start_new = false)
      curr_idx = @results.size
      if curr_idx == 0 || start_new
        result = RectClipOutPt2.new
        result.pt = pt
        result.op_next = result
        result.op_prev = result
        @op_container << result
        @results << result
        result
      else
        curr_idx -= 1
        prev_op = @results[curr_idx]
        return prev_op if prev_op.pt == pt
        result = RectClipOutPt2.new
        result.owner_idx = curr_idx
        result.pt = pt
        result.op_next = prev_op.op_next
        prev_op.op_next.op_prev = result
        prev_op.op_next = result
        result.op_prev = prev_op
        @results[curr_idx] = result
        @op_container << result
        result
      end
    end

    def add_corner(prev_loc, curr_loc)
      if heading_clockwise?(prev_loc, curr_loc)
        add(@rect_as_path[prev_loc])
      else
        add(@rect_as_path[curr_loc])
      end
    end

    def add_corner_adv(loc_box, is_clockwise)
      loc = loc_box
      if is_clockwise
        add(@rect_as_path[loc[0]])
        loc[0] = get_adjacent_location(loc[0], true)
      else
        loc[0] = get_adjacent_location(loc[0], false)
        add(@rect_as_path[loc[0]])
      end
    end

    def get_next_location(path, loc_box, i_box, high_i)
      loc = loc_box[0]
      i = i_box[0]
      case loc
      when LOCATION_LEFT
        i += 1 while i <= high_i && path[i].x <= @rect.left
        if i > high_i
        elsif path[i].x >= @rect.right
          loc_box[0] = LOCATION_RIGHT
        elsif path[i].y <= @rect.top
          loc_box[0] = LOCATION_TOP
        elsif path[i].y >= @rect.bottom
          loc_box[0] = LOCATION_BOTTOM
        else
          loc_box[0] = LOCATION_INSIDE
        end
      when LOCATION_TOP
        i += 1 while i <= high_i && path[i].y <= @rect.top
        if i > high_i
        elsif path[i].y >= @rect.bottom
          loc_box[0] = LOCATION_BOTTOM
        elsif path[i].x <= @rect.left
          loc_box[0] = LOCATION_LEFT
        elsif path[i].x >= @rect.right
          loc_box[0] = LOCATION_RIGHT
        else
          loc_box[0] = LOCATION_INSIDE
        end
      when LOCATION_RIGHT
        i += 1 while i <= high_i && path[i].x >= @rect.right
        if i > high_i
        elsif path[i].x <= @rect.left
          loc_box[0] = LOCATION_LEFT
        elsif path[i].y <= @rect.top
          loc_box[0] = LOCATION_TOP
        elsif path[i].y >= @rect.bottom
          loc_box[0] = LOCATION_BOTTOM
        else
          loc_box[0] = LOCATION_INSIDE
        end
      when LOCATION_BOTTOM
        i += 1 while i <= high_i && path[i].y >= @rect.bottom
        if i > high_i
        elsif path[i].y <= @rect.top
          loc_box[0] = LOCATION_TOP
        elsif path[i].x <= @rect.left
          loc_box[0] = LOCATION_LEFT
        elsif path[i].x >= @rect.right
          loc_box[0] = LOCATION_RIGHT
        else
          loc_box[0] = LOCATION_INSIDE
        end
      when LOCATION_INSIDE
        while i <= high_i
          if path[i].x < @rect.left
            loc_box[0] = LOCATION_LEFT
            break
          elsif path[i].x > @rect.right
            loc_box[0] = LOCATION_RIGHT
            break
          elsif path[i].y > @rect.bottom
            loc_box[0] = LOCATION_BOTTOM
            break
          elsif path[i].y < @rect.top
            loc_box[0] = LOCATION_TOP
            break
          else
            add(path[i])
            i += 1
          end
        end
      end
      i_box[0] = i
    end

    def execute_internal(path)
      return if path.size < 1
      high_i = path.size - 1
      prev = LOCATION_INSIDE
      loc_box = [LOCATION_INSIDE]
      crossing_loc = LOCATION_INSIDE
      first_cross = LOCATION_INSIDE
      ok_loc, loc = get_location(@rect, path[high_i])
      loc_box[0] = loc
      unless ok_loc
        i = high_i
        while i > 0
          ok_inner, pv = get_location(@rect, path[i - 1])
          prev = pv
          break if ok_inner
          i -= 1
        end
        if i == 0
          path.each { |pt| add(pt) }
          return
        end
        loc_box[0] = LOCATION_INSIDE if prev == LOCATION_INSIDE
      end
      starting_loc = loc_box[0]
      i_box = [0]
      i = 0
      while i <= high_i
        prev = loc_box[0]
        crossing_prev = crossing_loc
        get_next_location(path, loc_box, i_box, high_i)
        i = i_box[0]
        break if i > high_i
        prev_pt = i > 0 ? path[i - 1] : path[high_i]
        crossing_loc = loc_box[0]
        loc_inter = [crossing_loc]
        ok_ip, ip = get_intersection(@rect_as_path, path[i], prev_pt, loc_inter)
        crossing_loc = loc_inter[0]
        unless ok_ip
          if crossing_prev == LOCATION_INSIDE
            is_clockw = is_clockwise_corner?(prev, loc_box[0], prev_pt, path[i], @rect_mp)
            prev_walk = prev
            loop do
              @start_locs << prev_walk
              prev_walk = get_adjacent_location(prev_walk, is_clockw)
              break if prev_walk == loc_box[0]
            end
            crossing_loc = crossing_prev
          elsif prev != LOCATION_INSIDE && prev != loc_box[0]
            is_clockw = is_clockwise_corner?(prev, loc_box[0], prev_pt, path[i], @rect_mp)
            prev_box = [prev]
            loop do
              add_corner_adv(prev_box, is_clockw)
              break if prev_box[0] == loc_box[0]
            end
          end
          i += 1
          next
        end
        if loc_box[0] == LOCATION_INSIDE
          if first_cross == LOCATION_INSIDE
            first_cross = crossing_loc
            @start_locs << prev
          elsif prev != crossing_loc
            is_clockw = is_clockwise_corner?(prev, crossing_loc, prev_pt, path[i], @rect_mp)
            prev_box = [prev]
            loop do
              add_corner_adv(prev_box, is_clockw)
              break if prev_box[0] == crossing_loc
            end
          end
        elsif prev != LOCATION_INSIDE
          loc_box[0] = prev
          loc_inter2 = [loc_box[0]]
          _ok2, ip2 = get_intersection(@rect_as_path, prev_pt, path[i], loc_inter2)
          loc_box[0] = loc_inter2[0]
          if crossing_prev != LOCATION_INSIDE && crossing_prev != loc_box[0]
            add_corner(crossing_prev, loc_box[0])
          end
          if first_cross == LOCATION_INSIDE
            first_cross = loc_box[0]
            @start_locs << prev
          end
          loc_box[0] = crossing_loc
          add(ip2)
          if ip == ip2
            _, lv = get_location(@rect, path[i])
            loc_box[0] = lv
            add_corner(crossing_loc, loc_box[0])
            crossing_loc = loc_box[0]
            next
          end
        else
          loc_box[0] = crossing_loc
          first_cross = crossing_loc if first_cross == LOCATION_INSIDE
        end
        add(ip)
      end
      if first_cross == LOCATION_INSIDE
        if starting_loc != LOCATION_INSIDE
          if @path_bounds.contains_rect?(@rect) && path1_contains_path2(path, @rect_as_path)
            is_clockwise_path = start_locs_are_clockwise?(@start_locs)
            4.times do |j|
              k = is_clockwise_path ? j : (3 - j)
              add(@rect_as_path[k])
              add_to_edge(@edges[k * 2], @results[0])
            end
          end
        end
      elsif loc_box[0] != LOCATION_INSIDE && (loc_box[0] != first_cross || @start_locs.size > 2)
        if @start_locs.size > 0
          prev_box = [loc_box[0]]
          @start_locs.each do |loc2|
            next if prev_box[0] == loc2
            add_corner_adv(prev_box, heading_clockwise?(prev_box[0], loc2))
            prev_box[0] = loc2
          end
          loc_box[0] = prev_box[0]
        end
        if loc_box[0] != first_cross
          lb = [loc_box[0]]
          add_corner_adv(lb, heading_clockwise?(lb[0], first_cross))
          loc_box[0] = lb[0]
        end
      end
    end

    def check_edges
      @results.each_with_index do |op, ri|
        next unless op
        op2 = op
        loop do
          if Clipper2.is_collinear?(op2.op_prev.pt, op2.pt, op2.op_next.pt)
            if op2 == op
              op2 = unlink_op_back(op2)
              break unless op2
              op = op2.op_prev
            else
              op2 = unlink_op_back(op2)
              break unless op2
            end
          else
            op2 = op2.op_next
          end
          break if op2 == op
        end
        unless op2
          @results[ri] = nil
          next
        end
        @results[ri] = op
        edge_set1 = get_edges_for_pt(op.op_prev.pt, @rect)
        op2 = op
        loop do
          edge_set2 = get_edges_for_pt(op2.pt, @rect)
          if edge_set2 != 0 && !op2.edge
            combined = edge_set1 & edge_set2
            4.times do |j|
              next unless combined & (1 << j) != 0
              if heading_clockwise_edge?(op2.op_prev.pt, op2.pt, j)
                add_to_edge(@edges[j * 2], op2)
              else
                add_to_edge(@edges[j * 2 + 1], op2)
              end
            end
          end
          edge_set1 = edge_set2
          op2 = op2.op_next
          break if op2 == op
        end
      end
    end

    def tidy_edges(idx, cw, ccw)
      return if ccw.empty?
      is_horz = idx == 1 || idx == 3
      cw_toward_larger = idx == 1 || idx == 2
      i = 0
      j = 0
      while i < cw.size
        p1 = cw[i]
        if !p1 || p1.op_next == p1.op_prev
          cw[i] = nil
          i += 1
          j = 0
          next
        end
        j_lim = ccw.size
        j += 1 while j < j_lim && (!ccw[j] || ccw[j].op_next == ccw[j].op_prev)
        if j == j_lim
          i += 1
          j = 0
          next
        end
        if cw_toward_larger
          p1 = cw[i].op_prev
          p1a = cw[i]
          p2 = ccw[j]
          p2a = ccw[j].op_prev
        else
          p1 = cw[i]
          p1a = cw[i].op_prev
          p2 = ccw[j].op_prev
          p2a = ccw[j]
        end
        if (is_horz && !has_horz_overlap(p1.pt, p1a.pt, p2.pt, p2a.pt)) ||
            (!is_horz && !has_vert_overlap(p1.pt, p1a.pt, p2.pt, p2a.pt))
          j += 1
          next
        end
        is_rejoining = cw[i].owner_idx != ccw[j].owner_idx
        if is_rejoining
          @results[p2.owner_idx] = nil
          set_new_owner(p2, p1.owner_idx)
        end
        if cw_toward_larger
          p1.op_next = p2
          p2.op_prev = p1
          p1a.op_prev = p2a
          p2a.op_next = p1a
        else
          p1.op_prev = p2
          p2.op_next = p1
          p1a.op_next = p2a
          p2a.op_prev = p1a
        end
        unless is_rejoining
          new_idx = @results.size
          @results << p1a
          set_new_owner(p1a, new_idx)
        end
        op = cw_toward_larger ? p2 : p1
        op2 = cw_toward_larger ? p1a : p2a
        @results[op.owner_idx] = op
        @results[op2.owner_idx] = op2
        op_is_larger = if is_horz
                          op.pt.x > op.op_prev.pt.x
                        else
                          op.pt.y > op.op_prev.pt.y
                        end
        op2_is_larger = if is_horz
                          op2.pt.x > op2.op_prev.pt.x
                        else
                          op2.pt.y > op2.op_prev.pt.y
                        end
        if op.op_next == op.op_prev || op.pt == op.op_prev.pt
          if op2_is_larger == cw_toward_larger
            cw[i] = op2
            ccw[j] = nil
            j += 1
          else
            ccw[j] = op2
            cw[i] = nil
            i += 1
          end
        elsif op2.op_next == op2.op_prev || op2.pt == op2.op_prev.pt
          if op_is_larger == cw_toward_larger
            cw[i] = op
            ccw[j] = nil
            j += 1
          else
            ccw[j] = op
            cw[i] = nil
            i += 1
          end
        elsif op_is_larger == op2_is_larger
          if op_is_larger == cw_toward_larger
            cw[i] = op
            uncouple_edge(op2)
            add_to_edge(cw, op2)
            ccw[j] = nil
            j += 1
          else
            cw[i] = nil
            ccw[j] = op2
            uncouple_edge(op)
            add_to_edge(ccw, op)
            j = 0
            i += 1
          end
        else
          cw[i] = op if op_is_larger == cw_toward_larger
          ccw[j] = op unless op_is_larger == cw_toward_larger
          cw[i] = op2 if op2_is_larger == cw_toward_larger
          ccw[j] = op2 unless op2_is_larger == cw_toward_larger
        end
      end
    end

    def get_path(op)
      return [] if !op || op.op_next == op.op_prev
      op2 = op.op_next
      while op2 && op2 != op
        if Clipper2.is_collinear?(op2.op_prev.pt, op2.pt, op2.op_next.pt)
          op = op2.op_prev
          op2 = unlink_op(op2)
        else
          op2 = op2.op_next
        end
      end
      op = op2
      return [] unless op2
      result = [op.pt]
      op2 = op.op_next
      while op2 != op
        result << op2.pt
        op2 = op2.op_next
      end
      result
    end
  end

  class RectClipLines64 < RectClip64
    def execute(paths)
      result = []
      return result if @rect.is_empty?
      paths.each do |path|
        pathrec = Clipper2.get_bounds_path(path)
        next unless @rect.intersects?(pathrec)
        execute_internal_lines(path)
        @results.each do |op|
          next unless op
          tmp = get_path_lines(op)
          result << tmp unless tmp.empty?
        end
        @results.clear
        @op_container.clear
        @start_locs.clear
      end
      result
    end

    def execute_internal_lines(path)
      return if @rect.is_empty? || path.size < 2
      @results.clear
      @op_container.clear
      @start_locs.clear
      high_i = path.size - 1
      i = 1
      loc_box = [LOCATION_INSIDE]
      prev = LOCATION_INSIDE
      crossing_loc = LOCATION_INSIDE
      ok_loc, loc = get_location(@rect, path[0])
      loc_box[0] = loc
      unless ok_loc
        while i <= high_i
          ok_inner, pv = get_location(@rect, path[i])
          prev = pv
          break if ok_inner
          i += 1
        end
        if i > high_i
          path.each { |pt| add(pt) }
          return
        end
        loc_box[0] = LOCATION_INSIDE if prev == LOCATION_INSIDE
        i = 1
      end
      add(path[0]) if loc_box[0] == LOCATION_INSIDE
      while i <= high_i
        prev = loc_box[0]
        ib = [i]
        get_next_location(path, loc_box, ib, high_i)
        i = ib[0]
        break if i > high_i
        prev_pt = path[i - 1]
        crossing_loc = loc_box[0]
        loc_inter = [crossing_loc]
        ok_ip, ip = get_intersection(@rect_as_path, path[i], prev_pt, loc_inter)
        crossing_loc = loc_inter[0]
        unless ok_ip
          i += 1
          next
        end
        if loc_box[0] == LOCATION_INSIDE
          add(ip, true)
        elsif prev != LOCATION_INSIDE
          crossing_loc = prev
          loc_inter2 = [crossing_loc]
          _ok2, ip2 = get_intersection(@rect_as_path, prev_pt, path[i], loc_inter2)
          crossing_loc = loc_inter2[0]
          add(ip2, true)
          add(ip)
        else
          add(ip)
        end
        i += 1
      end
    end

    def get_path_lines(op)
      result = []
      return result if !op || op == op.op_next
      op = op.op_next
      result << op.pt
      op2 = op.op_next
      while op2 != op
        result << op2.pt
        op2 = op2.op_next
      end
      result
    end
  end

  module_function

  def normalize_rect(rect)
    return rect if rect.is_a?(Rect64)
    if rect.is_a?(RectD)
      Rect64.new(left: rect.left.round, top: rect.top.round, right: rect.right.round, bottom: rect.bottom.round)
    else
      Rect64.new(left: rect[0], top: rect[1], right: rect[2], bottom: rect[3])
    end
  end

  def rect_clip(rect, paths)
    rectangle = normalize_rect(rect)
    RectClip64.new(rectangle).execute(paths64(paths))
  end

  def rect_clip_lines(rect, paths)
    rectangle = normalize_rect(rect)
    RectClipLines64.new(rectangle).execute(paths64(paths))
  end
end
