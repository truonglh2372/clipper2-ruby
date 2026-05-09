require_relative "test_helper"
require_relative "clip_file_load"
require "json"

class UpstreamOffsetsTest < Minitest::Test
  include Clipper2TestHelpers

  OFFSETS_TXT = File.expand_path("fixtures/Offsets.txt", __dir__)

  def test_offsets
    text = File.read(OFFSETS_TXT)
    (1..2).each do |tn|
      data = ClipFileLoad.load_test_num(text, tn)
      refute_nil data
      co = Clipper2::ClipperOffset.new
      co.add_paths(data[:subjects], Clipper2::ROUND, Clipper2::POLYGON)
      outputs = co.execute(1)
      outer_pos = Clipper2.areas(outputs) > 0
      pos_cnt = outputs.count { |p| Clipper2.is_positive(p) }
      neg_cnt = outputs.size - pos_cnt
      if outer_pos
        assert_equal 1, pos_cnt
      else
        assert_equal 1, neg_cnt
      end
    end
  end

  def test_offsets2
    scale = 10.0
    delta = 10 * scale
    arc_tol = 0.25 * scale
    subject = [make_path([50, 50, 100, 50, 100, 150, 50, 150, 0, 100])]
    ec = [0]
    subject64 = Clipper2.scale_paths([Clipper2.path64(subject[0])], scale, scale, ec)
    c = Clipper2::ClipperOffset.new(2, arc_tol)
    c.add_paths(subject64, Clipper2::ROUND, Clipper2::POLYGON)
    solution = c.execute(delta)
    assert_equal 1, solution.length
    min_dist = delta * 2
    max_dist = 0.0
    subj0 = subject64[0]
    sol0 = solution[0]
    prev_pt = sol0[-1]
    sol0.each do |pt|
      subj0.each do |subj_pt|
        mp_x = (prev_pt.x + pt.x) / 2
        mp_y = (prev_pt.y + pt.y) / 2
        mp = Clipper2.point64(mp_x, mp_y)
        d = Clipper2.distance(mp, subj_pt)
        next unless d < delta * 2

        min_dist = d if d < min_dist
        max_dist = d if d > max_dist
      end
      prev_pt = pt
    end
    assert_operator min_dist + 1, :>=, delta - arc_tol
    assert_operator sol0.length, :<=, 21
  end

  def test_offsets3
    paths = JSON.parse(File.read(File.expand_path("fixtures/testoffsets3_paths.json", __dir__))).map { |pairs| Clipper2.path64(pairs) }
    solution = Clipper2.inflate_paths(paths, -209_715, Clipper2::MITER, Clipper2::POLYGON)
    assert_operator solution[0].length - paths[0].length, :<=, 1
  end

  def test_offsets4
    paths = [[[0, 0], [20_000, 200], [40_000, 0], [40_000, 50_000], [0, 50_000], [0, 0]]]
    solution = Clipper2.inflate_paths(paths, -5000, Clipper2::SQUARE, Clipper2::POLYGON)
    assert_operator (solution[0].length - 5).abs, :<=, 1
    paths = [[[0, 0], [20_000, 400], [40_000, 0], [40_000, 50_000], [0, 50_000], [0, 0]]]
    solution = Clipper2.inflate_paths(paths, -5000, Clipper2::SQUARE, Clipper2::POLYGON)
    assert_operator (solution[0].length - 5).abs, :<=, 1
    paths = [[[0, 0], [20_000, 400], [40_000, 0], [40_000, 50_000], [0, 50_000], [0, 0]]]
    solution = Clipper2.inflate_paths(paths, -5000, Clipper2::ROUND, Clipper2::POLYGON, 2, 100)
    assert_operator solution[0].length, :>, 5
    paths = [[[0, 0], [20_000, 1500], [40_000, 0], [40_000, 50_000], [0, 50_000], [0, 0]]]
    solution = Clipper2.inflate_paths(paths, -5000, Clipper2::ROUND, Clipper2::POLYGON, 2, 100)
    assert_operator solution[0].length, :>, 5
  end

  def test_offsets5
    paths = JSON.parse(File.read(File.expand_path("fixtures/offsets5_paths.json", __dir__))).map { |pairs| Clipper2.path64(pairs) }
    solution = Clipper2.inflate_paths(paths, -10_000, Clipper2::ROUND, Clipper2::POLYGON)
    assert_equal 2, solution.size
  end

  def test_offsets6
    paths = JSON.parse(File.read(File.expand_path("fixtures/testoffsets6_paths.json", __dir__))).map { |pairs| Clipper2.path64(pairs) }
    solution = Clipper2.inflate_paths(paths, -50, Clipper2::ROUND, Clipper2::POLYGON)
    assert_equal 2, solution.size
    neg = solution.select { |p| Clipper2.area(p) < 0 }.min_by { |p| Clipper2.area(p) }
    refute_nil neg
    assert_operator Clipper2.area(neg), :<, -47_500
  end

  def test_offsets7
    subject = [make_path([0, 0, 100, 0, 100, 100, 0, 100])]
    solution = Clipper2.inflate_paths(subject, -50, Clipper2::MITER, Clipper2::POLYGON)
    assert_empty solution
    subject.push(make_path([40, 60, 60, 60, 60, 40, 40, 40]))
    solution = Clipper2.inflate_paths(subject, 10, Clipper2::MITER, Clipper2::POLYGON)
    assert_equal 1, solution.size
    subject[0].reverse!
    subject[1].reverse!
    solution = Clipper2.inflate_paths(subject, 10, Clipper2::MITER, Clipper2::POLYGON)
    assert_equal 1, solution.size
    assert_operator Clipper2.area(solution[0]).abs, :>, Clipper2.area(Clipper2.path64(subject[0])).abs
    subject.pop
    solution = Clipper2.inflate_paths(subject, -50, Clipper2::MITER, Clipper2::POLYGON)
    assert_empty solution
  end

  def test_offsets8
    paths = JSON.parse(File.read(File.expand_path("fixtures/offsets8_subject.json", __dir__))).map { |pairs| Clipper2.path64(pairs) }
    offset = -50_329_979.277800001
    arc_tol = 5000
    solution = Clipper2.inflate_paths(paths, offset, Clipper2::ROUND, Clipper2::POLYGON, 2, arc_tol)
    refute_empty solution
    smallest_dist, largest_dist = offset_quality_sample_min_max(paths[0], solution[0], offset)
    off = offset.abs
    assert_operator smallest_dist, :>, arc_tol
    assert_operator largest_dist - off, :<=, off * 0.1 + arc_tol
  end

  def test_offsets9
    subject = [make_path([100, 100, 200, 100, 200, 400, 100, 400])]
    solution = Clipper2.inflate_paths(subject, 50, Clipper2::MITER, Clipper2::POLYGON)
    assert_equal 1, solution.size
    assert Clipper2.is_positive(solution[0])
    subject[0].reverse!
    solution = Clipper2.inflate_paths(subject, 50, Clipper2::MITER, Clipper2::POLYGON)
    assert_equal 1, solution.size
    assert_operator Clipper2.area(solution[0]).abs, :>, Clipper2.area(Clipper2.path64(subject[0])).abs
    refute Clipper2.is_positive(solution[0])
    co = Clipper2::ClipperOffset.new(2, 0, false, true)
    co.add_paths(subject, Clipper2::MITER, Clipper2::POLYGON)
    sol = []
    co.execute(50, sol)
    solution = sol
    assert_equal 1, solution.size
    assert_operator Clipper2.area(solution[0]).abs, :>, Clipper2.area(Clipper2.path64(subject[0])).abs
    assert Clipper2.is_positive(solution[0])
    subject.push(make_path([130, 130, 170, 130, 170, 370, 130, 370]))
    solution = Clipper2.inflate_paths(subject, 30, Clipper2::MITER, Clipper2::POLYGON)
    assert_equal 1, solution.size
    refute Clipper2.is_positive(solution[0])
    co.clear
    co.add_paths(subject, Clipper2::MITER, Clipper2::POLYGON)
    co.execute(30, sol)
    solution = sol
    assert_equal 1, solution.size
    assert_operator Clipper2.area(solution[0]).abs, :>, Clipper2.area(Clipper2.path64(subject[0])).abs
    assert Clipper2.is_positive(solution[0])
    solution = Clipper2.inflate_paths(subject, -15, Clipper2::MITER, Clipper2::POLYGON)
    assert_empty solution
  end

  def test_offsets10
    paths = JSON.parse(File.read(File.expand_path("fixtures/offsets10_subjects.json", __dir__))).map { |pairs| Clipper2.path64(pairs) }
    offseter = Clipper2::ClipperOffset.new(2, 104_857.61318750000)
    offseter.add_paths(paths, Clipper2::ROUND, Clipper2::POLYGON)
    solution = offseter.execute(-2_212_495.6382562499)
    assert_equal 2, solution.size
  end

  def test_offsets11
    subject = [make_path([-1, -1, -1, 11, 11, 11, 11, -1])]
    solution = Clipper2.inflate_paths(subject, -50, Clipper2::MITER, Clipper2::POLYGON)
    assert_empty solution
  end

  def test_offsets12
    subject = [[[667_680_768, -36_382_704], [737_202_688, -87_034_880], [742_581_888, -86_055_680], [747_603_968, -84_684_800]]]
    solution = Clipper2.inflate_paths(subject, -249_561_088, Clipper2::MITER, Clipper2::POLYGON)
    assert_empty solution
  end

  def test_offsets13
    subject1 = [[[0, 0], [0, 10], [10, 0]]]
    solution1 = Clipper2.inflate_paths(subject1, 2, Clipper2::MITER, Clipper2::POLYGON)
    area1 = Clipper2.area(solution1[0]).abs
    assert_in_delta 122, area1, 8
    subject2 = [[[0, 0], [0, 10], [10, 0]], [[0, 20]]]
    solution2 = Clipper2.inflate_paths(subject2, 2, Clipper2::MITER, Clipper2::POLYGON)
    area2 = Clipper2.area(solution2[0]).abs
    assert_in_delta area1, area2, 1e-6
  end

  def test_offsets14_inside_3mm_no_spike_at_two_ends
    raw_points = [
      [557.664, 875.132], [557.708, 875.128], [550.84, 866.117], [550.419, 865.539], [549.988, 864.945],
      [549.548, 864.335], [549.099, 863.709], [548.641, 863.067], [548.174, 862.411], [547.699, 861.739],
      [547.216, 861.052], [546.724, 860.35], [546.226, 859.634], [545.72, 858.903], [545.206, 858.158],
      [544.686, 857.398], [544.16, 856.625], [543.627, 855.838], [543.087, 855.037], [542.542, 854.223],
      [541.992, 853.395], [541.436, 852.555], [540.875, 851.701], [540.309, 850.835], [539.738, 849.956],
      [539.163, 849.064], [538.584, 848.161], [538.002, 847.245], [537.415, 846.317], [536.826, 845.378],
      [536.233, 844.427], [535.637, 843.464], [535.039, 842.491], [534.439, 841.506], [533.836, 840.51],
      [533.232, 839.504], [532.626, 838.487], [532.018, 837.46], [531.41, 836.422], [530.801, 835.375],
      [530.191, 834.317], [529.581, 833.25], [528.971, 832.174], [528.361, 831.088], [527.752, 829.993],
      [527.143, 828.889], [526.536, 827.776], [525.929, 826.654], [525.324, 825.524], [524.721, 824.385],
      [524.119, 823.239], [523.52, 822.084], [522.924, 820.922], [522.33, 819.751], [521.739, 818.574],
      [521.151, 817.389], [520.567, 816.197], [519.986, 814.998], [519.41, 813.792], [518.837, 812.58],
      [518.269, 811.361], [517.706, 810.136], [517.148, 808.905], [516.596, 807.668], [516.048, 806.425],
      [515.507, 805.177], [514.971, 803.923], [514.442, 802.664], [513.919, 801.4], [513.403, 800.131],
      [512.894, 798.857], [512.392, 797.578], [511.898, 796.296], [511.412, 795.009], [510.933, 793.718],
      [510.463, 792.423], [510.001, 791.124], [509.549, 789.822], [509.105, 788.517], [508.67, 787.208],
      [508.245, 785.896], [507.83, 784.582], [507.425, 783.265], [507.03, 781.945], [506.646, 780.623],
      [506.272, 779.299], [505.909, 777.971], [505.547, 776.627], [505.185, 775.267], [504.825, 773.889],
      [504.464, 772.494], [504.104, 771.084], [503.744, 769.657], [503.384, 768.214], [503.024, 766.756],
      [502.664, 765.283], [502.304, 763.795], [501.943, 762.293], [501.582, 760.776], [501.221, 759.246],
      [500.859, 757.702], [500.497, 756.146], [500.134, 754.576], [499.77, 752.994], [499.405, 751.399],
      [499.039, 749.793], [498.672, 748.175], [492.181, 719.215], [491.779, 717.444], [491.375, 715.668],
      [490.968, 713.887], [490.557, 712.1], [490.144, 710.31], [489.727, 708.515], [489.307, 706.716],
      [488.884, 704.914], [488.458, 703.109], [488.028, 701.301], [487.594, 699.49], [487.157, 697.677],
      [486.716, 695.862], [486.271, 694.046], [485.822, 692.228], [485.369, 690.409], [484.912, 688.59],
      [484.451, 686.771], [483.985, 684.951], [483.515, 683.132], [483.041, 681.314], [482.562, 679.496],
      [482.078, 677.68], [481.589, 675.865], [481.096, 674.053], [480.598, 672.243], [480.094, 670.435],
      [479.586, 668.63], [479.072, 666.829], [478.553, 665.031], [478.029, 663.237], [477.499, 661.447],
      [476.964, 659.662], [476.423, 657.881], [475.876, 656.106], [475.323, 654.336], [474.765, 652.572],
      [474.2, 650.814], [473.63, 649.063], [473.053, 647.319], [472.47, 645.581], [471.88, 643.851],
      [471.284, 642.129], [470.682, 640.415], [470.073, 638.709], [469.457, 637.012], [468.834, 635.324],
      [468.204, 633.645], [467.568, 631.976], [466.924, 630.317], [466.273, 628.669], [465.615, 627.031],
      [464.949, 625.404], [464.276, 623.788], [463.596, 622.184], [462.907, 620.592], [462.211, 619.012],
      [461.508, 617.444], [460.796, 615.89], [460.076, 614.349], [459.349, 612.821], [458.613, 611.307],
      [457.869, 609.808], [457.116, 608.323], [456.355, 606.852], [455.586, 605.397], [454.808, 603.957],
      [454.021, 602.534], [453.225, 601.126], [452.421, 599.735], [451.607, 598.36], [450.785, 597.003],
      [450.37, 596.33], [449.953, 595.662], [449.534, 594.999], [449.112, 594.34], [448.688, 593.686],
      [448.262, 593.036], [447.833, 592.391], [447.402, 591.75], [447.213, 591.471], [447.192, 591.449],
      [447.163, 591.452], [447.154, 591.478], [447.152, 591.517], [447.153, 591.558], [447.157, 591.596],
      [447.162, 591.622], [447.165, 591.649], [453.267, 633.809], [453.449, 635.166], [453.632, 636.535],
      [453.816, 637.916], [454.0, 639.308], [454.184, 640.71], [454.369, 642.123], [454.554, 643.546],
      [454.739, 644.978], [454.924, 646.418], [455.109, 647.868], [455.294, 649.325], [455.479, 650.789],
      [455.663, 652.261], [455.847, 653.739], [456.03, 655.224], [456.395, 658.209], [456.756, 661.212],
      [457.113, 664.231], [457.466, 667.262], [457.812, 670.3], [458.153, 673.342], [458.486, 676.385],
      [458.811, 679.424], [459.128, 682.456], [459.435, 685.478], [459.585, 686.983], [459.732, 688.485],
      [459.876, 689.982], [460.018, 691.474], [460.157, 692.96], [460.292, 694.441], [460.425, 695.915],
      [460.554, 697.382], [460.68, 698.842], [460.803, 700.295], [460.922, 701.739], [461.037, 703.174],
      [461.149, 704.6], [461.257, 706.017], [461.361, 707.423], [461.461, 708.819], [461.557, 710.204],
      [461.649, 711.577], [461.737, 712.939], [461.82, 714.288], [461.899, 715.624], [461.973, 716.947],
      [462.042, 718.256], [462.107, 719.551], [462.167, 720.831], [462.222, 722.096], [462.272, 723.346],
      [462.317, 724.579], [462.357, 725.801], [462.403, 727.062], [462.461, 728.334], [462.531, 729.617],
      [462.613, 730.911], [462.707, 732.216], [462.813, 733.531], [462.932, 734.857], [463.063, 736.192],
      [463.206, 737.536], [463.361, 738.89], [463.529, 740.253], [463.709, 741.625], [463.902, 743.004],
      [464.108, 744.392], [464.326, 745.788], [464.557, 747.192], [464.801, 748.602], [465.057, 750.02],
      [465.327, 751.444], [465.609, 752.874], [465.905, 754.311], [466.213, 755.754], [466.535, 757.202],
      [466.87, 758.655], [467.218, 760.114], [467.579, 761.577], [467.954, 763.044], [468.342, 764.516],
      [468.744, 765.991], [469.159, 767.47], [469.588, 768.952], [470.03, 770.438], [470.487, 771.926],
      [470.957, 773.416], [471.44, 774.909], [471.938, 776.403], [472.45, 777.899], [472.975, 779.396],
      [473.244, 780.146], [473.515, 780.895], [473.79, 781.644], [474.069, 782.394], [474.351, 783.144],
      [474.637, 783.893], [474.926, 784.643], [475.219, 785.393], [475.516, 786.143], [475.816, 786.893],
      [476.12, 787.642], [476.427, 788.392], [476.738, 789.141], [477.052, 789.89], [477.37, 790.639],
      [477.692, 791.388], [478.017, 792.136], [478.346, 792.884], [478.679, 793.631], [479.015, 794.378],
      [479.355, 795.125], [479.699, 795.871], [480.046, 796.617], [480.397, 797.362], [480.752, 798.107],
      [481.11, 798.85], [481.472, 799.594], [481.838, 800.336], [482.207, 801.078], [482.58, 801.819],
      [482.957, 802.559], [483.338, 803.298], [483.723, 804.037], [484.111, 804.774], [484.503, 805.511],
      [484.898, 806.246], [485.298, 806.981], [485.701, 807.714], [486.108, 808.447], [486.519, 809.178],
      [486.934, 809.908], [487.352, 810.637], [487.775, 811.365], [488.201, 812.091], [488.631, 812.816],
      [489.065, 813.54], [489.502, 814.262], [489.944, 814.983], [490.389, 815.703], [490.839, 816.421],
      [491.292, 817.138], [491.749, 817.852], [492.21, 818.566], [492.675, 819.278], [493.143, 819.988],
      [493.616, 820.696], [494.093, 821.403], [494.573, 822.108], [495.058, 822.811], [495.546, 823.512],
      [496.038, 824.211], [496.535, 824.909], [497.035, 825.604], [497.539, 826.298], [498.047, 826.99],
      [498.56, 827.679], [499.076, 828.366], [499.596, 829.052], [500.12, 829.735], [500.648, 830.416],
      [501.181, 831.094], [501.717, 831.771], [502.257, 832.445], [502.802, 833.117], [503.35, 833.786],
      [503.903, 834.453], [504.459, 835.118], [505.02, 835.78], [505.585, 836.44], [506.153, 837.097],
      [506.726, 837.751], [507.303, 838.403], [507.884, 839.052], [508.47, 839.699], [509.059, 840.343],
      [509.653, 840.984], [510.25, 841.622], [510.852, 842.257], [511.458, 842.89], [512.068, 843.52],
      [512.682, 844.146], [513.301, 844.77], [513.923, 845.391], [514.55, 846.008], [515.181, 846.623],
      [515.816, 847.235], [516.456, 847.843], [517.1, 848.448], [517.748, 849.05], [518.4, 849.649],
      [519.056, 850.244], [519.717, 850.836], [520.382, 851.425], [521.051, 852.01], [521.724, 852.592],
      [522.402, 853.171], [523.084, 853.746], [523.77, 854.317], [524.461, 854.885], [525.155, 856.01],
      [525.855, 856.566], [526.558, 857.12], [527.266, 857.669], [527.978, 858.215], [528.695, 858.756],
      [529.416, 859.294], [530.141, 859.828], [530.87, 860.358], [531.604, 860.885], [532.343, 861.407],
      [533.086, 861.925], [533.833, 862.439], [534.584, 862.949], [535.34, 863.455], [536.101, 863.956],
      [536.865, 864.454], [537.635, 864.947], [538.408, 865.436], [539.186, 865.92], [539.969, 866.401],
      [540.756, 866.876], [541.547, 867.348], [542.343, 867.815], [543.144, 868.277], [544.758, 868.735],
      [545.572, 869.189], [546.39, 869.637], [547.213, 870.081], [548.041, 870.521], [548.873, 870.956],
      [549.709, 871.386], [550.551, 871.811], [551.396, 872.231], [552.246, 872.647], [553.101, 873.057],
      [553.961, 873.463], [554.825, 873.864], [555.693, 874.26], [556.566, 874.651], [557.444, 875.036]
    ]
    points = raw_points.each_with_index.filter_map { |pt, i| (i % 6).zero? ? pt : nil }
    points << raw_points[-1] unless points[-1] == raw_points[-1]
    scale = 1000.0
    subject = [Clipper2.scale_path(Clipper2.path64(points), scale)]
    solution = Clipper2.inflate_paths(subject, -3000, Clipper2::ROUND, Clipper2::POLYGON, 2.0, 50)
    assert_equal 1, solution.length, "inward offset of a simple leaf must produce a single ring (no spike loops)"
    ring = solution.first
    subject_area = Clipper2.area(subject[0]).abs
    ring_area = Clipper2.area(ring).abs
    assert_operator ring_area, :<, subject_area, "offset ring must be smaller than subject"
    sb = Clipper2.bounds(subject)
    rb = Clipper2.bounds([ring])
    assert_operator rb.left - sb.left, :>=, 2900, "left margin must be at least ~3mm"
    assert_operator sb.right - rb.right, :>=, 2900, "right margin must be at least ~3mm"
    assert_operator rb.top - sb.top, :>=, 2900, "top margin must be at least ~3mm"
    assert_operator sb.bottom - rb.bottom, :>=, 2900, "bottom margin must be at least ~3mm"
    min_distance_from_ring_to_subject = ring_min_distance_to_path(ring, subject[0])
    assert_in_delta 3000, min_distance_from_ring_to_subject, 50, "every ring point must lie ~3mm from the subject boundary"
    first_anchor = Clipper2.point64((points[0][0] * scale).round, (points[0][1] * scale).round)
    last_anchor = Clipper2.point64((points[-1][0] * scale).round, (points[-1][1] * scale).round)
    assert_no_spike_near_anchor(ring, first_anchor)
    assert_no_spike_near_anchor(ring, last_anchor)
  end

  private

  def ring_min_distance_to_path(ring, path)
    closest = Float::INFINITY
    ring.each do |pt|
      pt_d = Clipper2.pointd(pt.x.to_f, pt.y.to_f)
      best = Float::INFINITY
      prev = path[-1]
      path.each do |sp|
        cp = Clipper2.get_closest_point_on_segment(pt_d, prev, sp)
        d = Clipper2.distance(pt_d, cp)
        best = d if d < best
        prev = sp
      end
      closest = best if best < closest
    end
    closest
  end

  def assert_no_spike_near_anchor(ring, anchor)
    idx = ring.each_index.min_by { |i| Clipper2.distance(ring[i], anchor) }
    refute_nil idx
    n = ring.length
    prev = ring[(idx - 1) % n]
    curr = ring[idx]
    nxt = ring[(idx + 1) % n]
    d_anchor = Clipper2.distance(curr, anchor)
    d1 = Clipper2.distance(prev, curr)
    d2 = Clipper2.distance(curr, nxt)
    assert_operator d_anchor, :<=, 15_000
    assert_operator d1, :<=, 18_000
    assert_operator d2, :<=, 18_000
  end

  def offset_quality_sample_min_max(subject_path, solution_path, delta)
    sub_vertex_count = 4
    sub_vertex_frac = 1.0 / sub_vertex_count
    desired_sqr = delta * delta
    smallest_sqr = desired_sqr
    largest_sqr = desired_sqr
    sol_prev = solution_path[-1]
    solution_path.each do |sol_pt0|
      sub_vertex_count.times do |i|
        sol_pt_x = sol_prev.x.to_f + (sol_pt0.x.to_f - sol_prev.x.to_f) * sub_vertex_frac * i
        sol_pt_y = sol_prev.y.to_f + (sol_pt0.y.to_f - sol_prev.y.to_f) * sub_vertex_frac * i
        sol_pt = Clipper2.pointd(sol_pt_x, sol_pt_y)
        closest_dist_sqr = Float::INFINITY
        sub_prev = subject_path[-1]
        subject_path.each do |sub_pt|
          closest = Clipper2.get_closest_point_on_segment(sol_pt, sub_prev, sub_pt)
          d = Clipper2.distance_sq(closest, sol_pt)
          closest_dist_sqr = d if d < closest_dist_sqr
          sub_prev = sub_pt
        end
        smallest_sqr = closest_dist_sqr if closest_dist_sqr < smallest_sqr
        largest_sqr = closest_dist_sqr if closest_dist_sqr > largest_sqr
      end
      sol_prev = sol_pt0
    end
    [Math.sqrt(smallest_sqr), Math.sqrt(largest_sqr)]
  end
end
