require_relative "core"

module Clipper2
  module TriangulationDelaunay
    EDGE_LOOSE = :loose
    EDGE_ASCEND = :ascend
    EDGE_DESCEND = :descend

    INTERSECT_NONE = :none
    INTERSECT_COLLINEAR = :collinear
    INTERSECT_INTERSECT = :intersect

    EDGE_CONTAINS_NEITHER = :neither
    EDGE_CONTAINS_LEFT = :left
    EDGE_CONTAINS_RIGHT = :right

    class Vertex2
      attr_accessor :pt, :edges, :inner_lm

      def initialize(pt)
        @pt = pt
        @edges = []
        @inner_lm = false
      end
    end

    class Edge
      attr_accessor :v_l, :v_r, :v_b, :v_t, :kind, :tri_a, :tri_b, :is_active, :next_e, :prev_e

      def initialize
        @kind = EDGE_LOOSE
        @is_active = false
        @next_e = nil
        @prev_e = nil
      end
    end

    class Triangle
      attr_accessor :edges

      def initialize(e1, e2, e3)
        @edges = [e1, e2, e3]
      end
    end

    class Engine
      def initialize(use_delaunay = true)
        @use_delaunay = use_delaunay
        @all_vertices = []
        @all_edges = []
        @all_triangles = []
        @pending_delaunay_stack = []
        @horz_edge_stack = []
        @loc_min_stack = []
        @first_active = nil
        @lowermost_vertex = nil
      end

      def execute(paths, tri_result_box)
        unless add_paths(paths)
          tri_result_box[0] = :no_polygons
          return []
        end

        if @lowermost_vertex.inner_lm
          until @loc_min_stack.empty?
            lm = @loc_min_stack.pop
            lm.inner_lm = !lm.inner_lm
          end
          @all_edges.each do |e|
            if e.kind == EDGE_ASCEND
              e.kind = EDGE_DESCEND
            elsif e.kind == EDGE_DESCEND
              e.kind = EDGE_ASCEND
            end
          end
        else
          @loc_min_stack.clear
        end

        @all_edges.sort_by! { |e| e.v_l.pt.x }
        unless fixup_edge_intersects
          cleanup
          tri_result_box[0] = :paths_intersect
          return []
        end

        @all_vertices.sort_by! { |v| [-v.pt.y, v.pt.x] }
        merge_dup_or_collinear_vertices

        curr_y = @all_vertices[0].pt.y
        @all_vertices.each do |v|
          next if v.edges.empty?
          if v.pt.y != curr_y
            until @loc_min_stack.empty?
              lm = @loc_min_stack.pop
              e = create_inner_loc_min_loose_edge(lm)
              unless e
                cleanup
                tri_result_box[0] = :fail
                return []
              end
              if horizontal_edge?(e)
                if e.v_l == e.v_b
                  do_triangulate_left(e, e.v_b, curr_y)
                else
                  do_triangulate_right(e, e.v_b, curr_y)
                end
              else
                do_triangulate_left(e, e.v_b, curr_y)
                unless edge_completed?(e)
                  do_triangulate_right(e, e.v_b, curr_y)
                end
              end
              add_edge_to_actives(lm.edges[0])
              add_edge_to_actives(lm.edges[1])
            end

            until @horz_edge_stack.empty?
              e = @horz_edge_stack.pop
              next if edge_completed?(e)
              if e.v_b == e.v_l
                if left_edge?(e)
                  do_triangulate_left(e, e.v_b, curr_y)
                end
              elsif right_edge?(e)
                do_triangulate_right(e, e.v_b, curr_y)
              end
            end
            curr_y = v.pt.y
          end

          i = v.edges.length - 1
          while i >= 0
            if i >= v.edges.length
              i -= 1
              next
            end
            e = v.edges[i]
            if edge_completed?(e) || loose_edge?(e)
              i -= 1
              next
            end

            if v == e.v_b
              if horizontal_edge?(e)
                @horz_edge_stack.push(e)
              end
              unless v.inner_lm
                add_edge_to_actives(e)
              end
            else
              if horizontal_edge?(e)
                @horz_edge_stack.push(e)
              elsif left_edge?(e)
                do_triangulate_left(e, e.v_b, v.pt.y)
              else
                do_triangulate_right(e, e.v_b, v.pt.y)
              end
            end
            i -= 1
          end

          @loc_min_stack.push(v) if v.inner_lm
        end

        until @horz_edge_stack.empty?
          e = @horz_edge_stack.pop
          if !edge_completed?(e) && e.v_b == e.v_l
            do_triangulate_left(e, e.v_b, curr_y)
          end
        end

        if @use_delaunay
          until @pending_delaunay_stack.empty?
            e = @pending_delaunay_stack.pop
            force_legal(e)
          end
        end

        res = []
        @all_triangles.each do |tri|
          p = path_from_triangle(tri)
          cps = Clipper2.cross_product_sign(p[0], p[1], p[2])
          next if cps == 0
          p.reverse! if cps < 0
          res << p
        end

        cleanup
        tri_result_box[0] = :success
        res
      end

      private

      def cleanup
        @all_vertices.clear
        @all_edges.clear
        @all_triangles.clear
        @pending_delaunay_stack.clear
        @horz_edge_stack.clear
        @loc_min_stack.clear
        @first_active = nil
        @lowermost_vertex = nil
      end

      def loose_edge?(e)
        e.kind == EDGE_LOOSE
      end

      def left_edge?(e)
        e.kind == EDGE_ASCEND
      end

      def right_edge?(e)
        e.kind == EDGE_DESCEND
      end

      def horizontal_edge?(e)
        e.v_b.pt.y == e.v_t.pt.y
      end

      def left_turning(p1, p2, p3)
        Clipper2.cross_product_sign(p1, p2, p3) < 0
      end

      def right_turning(p1, p2, p3)
        Clipper2.cross_product_sign(p1, p2, p3) > 0
      end

      def edge_completed?(edge)
        return false unless edge.tri_a
        return true if edge.tri_b
        !loose_edge?(edge)
      end

      def edge_contains(edge, v)
        return EDGE_CONTAINS_LEFT if edge.v_l == v
        return EDGE_CONTAINS_RIGHT if edge.v_r == v
        EDGE_CONTAINS_NEITHER
      end

      def self.angle(a, b, c)
        abx = (b.x - a.x).to_f
        aby = (b.y - a.y).to_f
        bcx = (b.x - c.x).to_f
        bcy = (b.y - c.y).to_f
        dp = abx * bcx + aby * bcy
        cp = abx * bcy - aby * bcx
        Math.atan2(cp, dp)
      end

      def loc_min_angle(v)
        asc, des =
          if v.edges[0].kind == EDGE_ASCEND
            [0, 1]
          else
            [1, 0]
          end
        self.class.angle(v.edges[des].v_t.pt, v.pt, v.edges[asc].v_t.pt)
      end

      def remove_edge_from_vertex(vert, edge)
        ix = vert.edges.index(edge)
        raise "triangulation vertex edge missing" unless ix
        vert.edges.delete_at(ix)
      end

      def self.find_loc_min_idx(path, len, idx_box)
        idx = idx_box[0]
        return false if len < 3
        i0 = idx
        n = (idx + 1) % len
        while path[n].y <= path[idx].y
          idx = n
          n = (n + 1) % len
          return false if idx == i0
        end
        while path[n].y >= path[idx].y
          idx = n
          n = (n + 1) % len
        end
        idx_box[0] = idx
        true
      end

      def self.prev_idx(idx, len)
        idx.zero? ? len - 1 : idx - 1
      end

      def self.next_idx(idx, len)
        (idx + 1) % len
      end

      def find_linking_edge(vert1, vert2, prefer_ascending)
        res = nil
        vert1.edges.each do |e|
          next unless e.v_l == vert2 || e.v_r == vert2
          if loose_edge?(e) || ((e.kind == EDGE_ASCEND) == prefer_ascending)
            return e
          end
          res = e
        end
        res
      end

      def path_from_triangle(tri)
        res = []
        res << tri.edges[0].v_l.pt
        res << tri.edges[0].v_r.pt
        e = tri.edges[1]
        if e.v_l.pt == res[0] || e.v_l.pt == res[1]
          res << e.v_r.pt
        else
          res << e.v_l.pt
        end
        res
      end

      def self.in_circle_test(pt_a, pt_b, pt_c, pt_d)
        m00 = (pt_a.x - pt_d.x).to_f
        m01 = (pt_a.y - pt_d.y).to_f
        m02 = m00 * m00 + m01 * m01
        m10 = (pt_b.x - pt_d.x).to_f
        m11 = (pt_b.y - pt_d.y).to_f
        m12 = m10 * m10 + m11 * m11
        m20 = (pt_c.x - pt_d.x).to_f
        m21 = (pt_c.y - pt_d.y).to_f
        m22 = m20 * m20 + m21 * m21
        m00 * (m11 * m22 - m21 * m12) -
          m10 * (m01 * m22 - m21 * m02) +
          m20 * (m01 * m12 - m11 * m02)
      end

      def shortest_dist_from_segment(pt, seg_pt1, seg_pt2)
        dx = (seg_pt2.x - seg_pt1.x).to_f
        dy = (seg_pt2.y - seg_pt1.y).to_f
        ax = (pt.x - seg_pt1.x).to_f
        ay = (pt.y - seg_pt1.y).to_f
        q_num = ax * dx + ay * dy
        return Clipper2.distance_sq(pt, seg_pt1) if q_num < 0
        dsq = dx * dx + dy * dy
        return Clipper2.distance_sq(pt, seg_pt2) if q_num > dsq
        num = ax * dy - dx * ay
        (num * num) / dsq
      end

      def self.segs_intersect(s1a, s1b, s2a, s2b)
        return INTERSECT_NONE if s1a == s2a || s1b == s2a || s1b == s2b

        dy1 = (s1b.y - s1a.y).to_f
        dx1 = (s1b.x - s1a.x).to_f
        dy2 = (s2b.y - s2a.y).to_f
        dx2 = (s2b.x - s2a.x).to_f
        cp = dy1 * dx2 - dy2 * dx1
        return INTERSECT_COLLINEAR if cp == 0

        t = (s1a.x - s2a.x) * dy2 - (s1a.y - s2a.y) * dx2
        if t >= 0
          return INTERSECT_NONE if cp < 0 || t >= cp
        else
          return INTERSECT_NONE if cp > 0 || t <= cp
        end

        t = (s1a.x - s2a.x) * dy1 - (s1a.y - s2a.y) * dx1
        if t >= 0
          return INTERSECT_INTERSECT if cp > 0 && t < cp
        else
          return INTERSECT_INTERSECT if cp < 0 && t > cp
        end
        INTERSECT_NONE
      end

      def force_legal(edge)
        return unless edge.tri_a && edge.tri_b

        vert_a = nil
        vert_b = nil
        edges_a = [nil, nil, nil]
        edges_b = [nil, nil, nil]

        3.times do |i|
          next if edge.tri_a.edges[i] == edge
          case edge_contains(edge.tri_a.edges[i], edge.v_l)
          when EDGE_CONTAINS_LEFT
            edges_a[1] = edge.tri_a.edges[i]
            vert_a = edge.tri_a.edges[i].v_r
          when EDGE_CONTAINS_RIGHT
            edges_a[1] = edge.tri_a.edges[i]
            vert_a = edge.tri_a.edges[i].v_l
          else
            edges_b[1] = edge.tri_a.edges[i]
          end
        end

        3.times do |i|
          next if edge.tri_b.edges[i] == edge
          case edge_contains(edge.tri_b.edges[i], edge.v_l)
          when EDGE_CONTAINS_LEFT
            edges_a[2] = edge.tri_b.edges[i]
            vert_b = edge.tri_b.edges[i].v_r
          when EDGE_CONTAINS_RIGHT
            edges_a[2] = edge.tri_b.edges[i]
            vert_b = edge.tri_b.edges[i].v_l
          else
            edges_b[2] = edge.tri_b.edges[i]
          end
        end

        return if Clipper2.cross_product_sign(vert_a.pt, edge.v_l.pt, edge.v_r.pt) == 0

        ict_result = self.class.in_circle_test(vert_a.pt, edge.v_l.pt, edge.v_r.pt, vert_b.pt)
        return if ict_result == 0 ||
          (right_turning(vert_a.pt, edge.v_l.pt, edge.v_r.pt) == (ict_result < 0))

        edge.v_l = vert_a
        edge.v_r = vert_b

        edge.tri_a.edges[0] = edge
        1.upto(2) do |i|
          edge.tri_a.edges[i] = edges_a[i]
          raise "triangulation force_legal edges_a" unless edges_a[i]
          @pending_delaunay_stack.push(edges_a[i]) if loose_edge?(edges_a[i])
          next if edges_a[i].tri_a == edge.tri_a || edges_a[i].tri_b == edge.tri_a

          if edges_a[i].tri_a == edge.tri_b
            edges_a[i].tri_a = edge.tri_a
          elsif edges_a[i].tri_b == edge.tri_b
            edges_a[i].tri_b = edge.tri_a
          else
            raise "triangulation force_legal tri patch a"
          end
        end

        edge.tri_b.edges[0] = edge
        1.upto(2) do |i|
          edge.tri_b.edges[i] = edges_b[i]
          raise "triangulation force_legal edges_b" unless edges_b[i]
          @pending_delaunay_stack.push(edges_b[i]) if loose_edge?(edges_b[i])
          next if edges_b[i].tri_a == edge.tri_b || edges_b[i].tri_b == edge.tri_b

          if edges_b[i].tri_a == edge.tri_a
            edges_b[i].tri_a = edge.tri_b
          elsif edges_b[i].tri_b == edge.tri_a
            edges_b[i].tri_b = edge.tri_b
          else
            raise "triangulation force_legal tri patch b"
          end
        end
      end

      def create_edge(v1, v2, k)
        res = Edge.new
        @all_edges << res
        if v1.pt.y == v2.pt.y
          res.v_b = v1
          res.v_t = v2
        elsif v1.pt.y < v2.pt.y
          res.v_b = v2
          res.v_t = v1
        else
          res.v_b = v1
          res.v_t = v2
        end

        if v1.pt.x <= v2.pt.x
          res.v_l = v1
          res.v_r = v2
        else
          res.v_l = v2
          res.v_r = v1
        end
        res.kind = k
        v1.edges.push(res)
        v2.edges.push(res)

        if k == EDGE_LOOSE
          @pending_delaunay_stack.push(res)
          add_edge_to_actives(res)
        end
        res
      end

      def create_triangle(e1, e2, e3)
        res = Triangle.new(e1, e2, e3)
        @all_triangles << res
        3.times do |i|
          er = res.edges[i]
          if er.tri_a
            er.tri_b = res
            remove_edge_from_actives(er)
          else
            er.tri_a = res
            remove_edge_from_actives(er) unless loose_edge?(er)
          end
        end
        res
      end

      def remove_intersection(e1, e2)
        v = e1.v_l
        tmp_e = e2
        d = shortest_dist_from_segment(e1.v_l.pt, e2.v_l.pt, e2.v_r.pt)
        d2 = shortest_dist_from_segment(e1.v_r.pt, e2.v_l.pt, e2.v_r.pt)
        if d2 < d
          d = d2
          v = e1.v_r
        end
        d2 = shortest_dist_from_segment(e2.v_l.pt, e1.v_l.pt, e1.v_r.pt)
        if d2 < d
          d = d2
          tmp_e = e1
          v = e2.v_l
        end
        d2 = shortest_dist_from_segment(e2.v_r.pt, e1.v_l.pt, e1.v_r.pt)
        if d2 < d
          d = d2
          tmp_e = e1
          v = e2.v_r
        end
        return false if d > 1.000

        v2 = tmp_e.v_t
        remove_edge_from_vertex(v2, tmp_e)
        if tmp_e.v_l == v2
          tmp_e.v_l = v
        else
          tmp_e.v_r = v
        end
        tmp_e.v_t = v
        v.edges.push(tmp_e)
        v.inner_lm = false
        if tmp_e.v_b.inner_lm && loc_min_angle(tmp_e.v_b) <= 0
          tmp_e.v_b.inner_lm = false
        end
        create_edge(v, v2, tmp_e.kind)
        true
      end

      def fixup_edge_intersects
        @all_edges.each_with_index do |e1, i1|
          ((i1 + 1)...@all_edges.length).each do |i2|
            e2 = @all_edges[i2]
            break if e2.v_l.pt.x >= e1.v_r.pt.x

            next unless e2.v_t.pt.y < e1.v_b.pt.y && e2.v_b.pt.y > e1.v_t.pt.y &&
              self.class.segs_intersect(e2.v_l.pt, e2.v_r.pt, e1.v_l.pt, e1.v_r.pt) == INTERSECT_INTERSECT

            return false unless remove_intersection(e2, e1)
          end
        end
        true
      end

      def split_edge(long_e, short_e)
        old_t = long_e.v_t
        new_t = short_e.v_t
        remove_edge_from_vertex(old_t, long_e)
        long_e.v_t = new_t
        if long_e.v_l == old_t
          long_e.v_l = new_t
        else
          long_e.v_r = new_t
        end
        new_t.edges.push(long_e)
        create_edge(new_t, old_t, long_e.kind)
      end

      def merge_dup_or_collinear_vertices
        return if @all_vertices.length < 2

        v_iter1 = 0
        (1...@all_vertices.length).each do |v_iter2|
          v1 = @all_vertices[v_iter1]
          v2 = @all_vertices[v_iter2]
          if v2.pt != v1.pt
            v_iter1 = v_iter2
            next
          end

          v1.inner_lm = false unless v1.inner_lm && v2.inner_lm

          v2.edges.each do |e|
            e.v_b = v1 if e.v_b == v2
            e.v_t = v1 if e.v_t == v2
            e.v_l = v1 if e.v_l == v2
            e.v_r = v1 if e.v_r == v2
          end
          v1.edges.concat(v2.edges)
          v2.edges.clear

          v1.edges.each_with_index do |_e, it_e|
            next if it_e >= v1.edges.length

            e1 = v1.edges[it_e]
            next if horizontal_edge?(e1) || e1.v_b != v1

            ((it_e + 1)...v1.edges.length).each do |it_e2|
              e2 = v1.edges[it_e2]
              next if e2.v_b != v1 || e1.v_t.pt.y == e2.v_t.pt.y
              next if Clipper2.cross_product_sign(e1.v_t.pt, v1.pt, e2.v_t.pt) != 0

              if e1.v_t.pt.y < e2.v_t.pt.y
                split_edge(e1, e2)
              else
                split_edge(e2, e1)
              end
              break
            end
          end
        end
      end

      def create_inner_loc_min_loose_edge(v_above)
        return nil unless @first_active

        x_above = v_above.pt.x
        y_above = v_above.pt.y
        e = @first_active
        e_below = nil
        best_d = -1.0
        while e
          if e.v_l.pt.x <= x_above && e.v_r.pt.x >= x_above &&
              e.v_b.pt.y >= y_above && e.v_b != v_above && e.v_t != v_above &&
              !left_turning(e.v_l.pt, v_above.pt, e.v_r.pt)
            d = shortest_dist_from_segment(v_above.pt, e.v_l.pt, e.v_r.pt)
            if !e_below || d < best_d
              e_below = e
              best_d = d
            end
          end
          e = e.next_e
        end
        return nil unless e_below

        v_best = e_below.v_t.pt.y <= y_above ? e_below.v_b : e_below.v_t
        x_best = v_best.pt.x
        y_best = v_best.pt.y

        e = @first_active
        if x_best < x_above
          while e
            if e.v_r.pt.x > x_best && e.v_l.pt.x < x_above &&
                e.v_b.pt.y > y_above && e.v_t.pt.y < y_best &&
                self.class.segs_intersect(e.v_b.pt, e.v_t.pt, v_best.pt, v_above.pt) == INTERSECT_INTERSECT
              v_best = e.v_t.pt.y > y_above ? e.v_t : e.v_b
              x_best = v_best.pt.x
              y_best = v_best.pt.y
            end
            e = e.next_e
          end
        else
          while e
            if e.v_r.pt.x < x_best && e.v_l.pt.x > x_above &&
                e.v_b.pt.y > y_above && e.v_t.pt.y < y_best &&
                self.class.segs_intersect(e.v_b.pt, e.v_t.pt, v_best.pt, v_above.pt) == INTERSECT_INTERSECT
              v_best = e.v_t.pt.y > y_above ? e.v_t : e.v_b
              x_best = v_best.pt.x
              y_best = v_best.pt.y
            end
            e = e.next_e
          end
        end
        create_edge(v_best, v_above, EDGE_LOOSE)
      end

      def horizontal_between(v1, v2)
        y = v1.pt.y
        if v1.pt.x > v2.pt.x
          l = v2.pt.x
          r = v1.pt.x
        else
          l = v1.pt.x
          r = v2.pt.x
        end

        res = @first_active
        while res
          if res.v_l.pt.y == y && res.v_r.pt.y == y &&
              res.v_l.pt.x >= l && res.v_r.pt.x <= r &&
              (res.v_l.pt.x != l || res.v_l.pt.x != r)
            return res
          end
          res = res.next_e
        end
        nil
      end

      def do_triangulate_left(edge, pivot, min_y)
        v_alt = nil
        e_alt = nil
        v = edge.v_b == pivot ? edge.v_t : edge.v_b

        pivot.edges.each do |e|
          next if e == edge || !e.is_active
          v_x = e.v_t == pivot ? e.v_b : e.v_t
          next if v_x == v

          cps = Clipper2.cross_product_sign(v.pt, pivot.pt, v_x.pt)
          if cps == 0
            next if (v.pt.x > pivot.pt.x) == (pivot.pt.x > v_x.pt.x)
          elsif cps > 0 || (v_alt && !left_turning(v_x.pt, pivot.pt, v_alt.pt))
            next
          end
          v_alt = v_x
          e_alt = e
        end

        return unless v_alt && v_alt.pt.y >= min_y

        if v_alt.pt.y < pivot.pt.y
          return if left_edge?(e_alt)
        elsif v_alt.pt.y > pivot.pt.y
          return if right_edge?(e_alt)
        end

        e_x = find_linking_edge(v_alt, v, v_alt.pt.y < v.pt.y)
        unless e_x
          if v_alt.pt.y == v.pt.y && v.pt.y == min_y && horizontal_between(v_alt, v)
            return
          end
          e_x = create_edge(v_alt, v, EDGE_LOOSE)
        end

        create_triangle(edge, e_alt, e_x)
        do_triangulate_left(e_x, v_alt, min_y) unless edge_completed?(e_x)
      end

      def do_triangulate_right(edge, pivot, min_y)
        v_alt = nil
        e_alt = nil
        v = edge.v_b == pivot ? edge.v_t : edge.v_b

        pivot.edges.each do |e|
          next if e == edge || !e.is_active
          v_x = e.v_t == pivot ? e.v_b : e.v_t
          next if v_x == v

          cps = Clipper2.cross_product_sign(v.pt, pivot.pt, v_x.pt)
          if cps == 0
            next if (v.pt.x > pivot.pt.x) == (pivot.pt.x > v_x.pt.x)
          elsif cps < 0 || (v_alt && !right_turning(v_x.pt, pivot.pt, v_alt.pt))
            next
          end
          v_alt = v_x
          e_alt = e
        end

        return unless v_alt && v_alt.pt.y >= min_y

        if v_alt.pt.y < pivot.pt.y
          return if right_edge?(e_alt)
        elsif v_alt.pt.y > pivot.pt.y
          return if left_edge?(e_alt)
        end

        e_x = find_linking_edge(v_alt, v, v_alt.pt.y > v.pt.y)
        unless e_x
          if v_alt.pt.y == v.pt.y && v.pt.y == min_y && horizontal_between(v_alt, v)
            return
          end
          e_x = create_edge(v_alt, v, EDGE_LOOSE)
        end

        create_triangle(edge, e_x, e_alt)
        do_triangulate_right(e_x, v_alt, min_y) unless edge_completed?(e_x)
      end

      def add_edge_to_actives(edge)
        return if edge.is_active

        edge.prev_e = nil
        edge.next_e = @first_active
        edge.is_active = true
        @first_active.prev_e = edge if @first_active
        @first_active = edge
      end

      def remove_edge_from_actives(edge)
        remove_edge_from_vertex(edge.v_b, edge)
        remove_edge_from_vertex(edge.v_t, edge)

        prev = edge.prev_e
        next_e = edge.next_e
        next_e.prev_e = prev if next_e
        prev.next_e = next_e if prev
        edge.is_active = false
        @first_active = next_e if @first_active == edge
      end

      def dist_sqr(a, b)
        Clipper2.distance_sq(a, b)
      end

      def add_path(path)
        len = path.length
        idx_box = [0]
        return unless self.class.find_loc_min_idx(path, len, idx_box)

        i0 = idx_box[0]
        i_prev = self.class.prev_idx(i0, len)
        while path[i_prev] == path[i0]
          i_prev = self.class.prev_idx(i_prev, len)
        end
        i_next = self.class.next_idx(i0, len)

        i = i0
        while Clipper2.cross_product_sign(path[i_prev], path[i], path[i_next]) == 0
          return unless self.class.find_loc_min_idx(path, len, idx_box)
          i = idx_box[0]
          return if i == i0
          i_prev = self.class.prev_idx(i, len)
          while path[i_prev] == path[i]
            i_prev = self.class.prev_idx(i_prev, len)
          end
          i_next = self.class.next_idx(i, len)
        end

        vert_cnt = @all_vertices.length
        v0 = Vertex2.new(path[i])
        @all_vertices << v0

        v0.inner_lm = true if left_turning(path[i_prev], path[i], path[i_next])
        v_prev = v0
        i = i_next

        loop do
          @loc_min_stack.push(v_prev)

          if !@lowermost_vertex ||
              v_prev.pt.y > @lowermost_vertex.pt.y ||
              (v_prev.pt.y == @lowermost_vertex.pt.y && v_prev.pt.x < @lowermost_vertex.pt.x)
            @lowermost_vertex = v_prev
          end

          i_next = self.class.next_idx(i, len)
          if Clipper2.cross_product_sign(v_prev.pt, path[i], path[i_next]) == 0
            i = i_next
            next
          end

          while path[i].y <= v_prev.pt.y
            v = Vertex2.new(path[i])
            @all_vertices << v
            create_edge(v_prev, v, EDGE_ASCEND)
            v_prev = v
            i = i_next
            i_next = self.class.next_idx(i, len)

            while Clipper2.cross_product_sign(v_prev.pt, path[i], path[i_next]) == 0
              i = i_next
              i_next = self.class.next_idx(i, len)
            end
          end

          v_prev_prev = v_prev
          while i != i0 && path[i].y >= v_prev.pt.y
            v = Vertex2.new(path[i])
            @all_vertices << v
            create_edge(v, v_prev, EDGE_DESCEND)
            v_prev_prev = v_prev
            v_prev = v
            i = i_next
            i_next = self.class.next_idx(i, len)

            while Clipper2.cross_product_sign(v_prev.pt, path[i], path[i_next]) == 0
              i = i_next
              i_next = self.class.next_idx(i, len)
            end
          end

          break if i == i0

          v_prev.inner_lm = true if left_turning(v_prev_prev.pt, v_prev.pt, path[i])
        end

        create_edge(v0, v_prev, EDGE_DESCEND)

        len_new = @all_vertices.length - vert_cnt
        i = vert_cnt
        if len_new < 3 || (len_new == 3 &&
            (dist_sqr(@all_vertices[i].pt, @all_vertices[i + 1].pt) <= 1 ||
              dist_sqr(@all_vertices[i + 1].pt, @all_vertices[i + 2].pt) <= 1 ||
              dist_sqr(@all_vertices[i + 2].pt, @all_vertices[i].pt) <= 1))
          vert_cnt.upto(@all_vertices.length - 1) { |j| @all_vertices[j].edges.clear }
        end
      end

      def add_paths(paths)
        total = paths.sum(&:length)
        return false if total.zero?

        paths.each { |path| add_path(path) }
        @all_vertices.length > 2
      end
    end
  end
end
