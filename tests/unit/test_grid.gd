extends GutTest
## Grid：正交折线路径栅格化、沿线取点、格中心换算。

const GridScript = preload("res://src/core/battle/grid.gd")

const WPS: Array = [Vector2i(-1, 1), Vector2i(13, 1), Vector2i(13, 8), Vector2i(2, 8)]

func test_rasterizes_path_cells():
	var g = GridScript.new(16, 10, WPS)
	assert_true(g.is_path(Vector2i(0, 1)))
	assert_true(g.is_path(Vector2i(13, 4)))
	assert_true(g.is_path(Vector2i(7, 8)))
	assert_false(g.is_path(Vector2i(5, 5)))

func test_in_bounds():
	var g = GridScript.new(16, 10, WPS)
	assert_true(g.in_bounds(Vector2i(0, 0)))
	assert_true(g.in_bounds(Vector2i(15, 9)))
	assert_false(g.in_bounds(Vector2i(-1, 1)))
	assert_false(g.in_bounds(Vector2i(16, 0)))

func test_path_length_sums_segments():
	var g = GridScript.new(16, 10, WPS)
	assert_almost_eq(g.path_length, 32.0, 0.001)  # 14 + 7 + 11

func test_point_at_ends_corners_and_clamp():
	var g = GridScript.new(16, 10, WPS)
	var p0: Vector2 = g.point_at(0.0)
	assert_almost_eq(p0.x, -0.5, 0.001)
	assert_almost_eq(p0.y, 1.5, 0.001)
	var neg: Vector2 = g.point_at(-3.0)
	assert_almost_eq(neg.x, -0.5, 0.001)  # 负距离截断到起点
	var corner: Vector2 = g.point_at(14.0)
	assert_almost_eq(corner.x, 13.5, 0.001)
	assert_almost_eq(corner.y, 1.5, 0.001)
	var down: Vector2 = g.point_at(15.0)
	assert_almost_eq(down.x, 13.5, 0.001)
	assert_almost_eq(down.y, 2.5, 0.001)
	var end: Vector2 = g.point_at(32.0)
	assert_almost_eq(end.x, 2.5, 0.001)
	assert_almost_eq(end.y, 8.5, 0.001)
	var over: Vector2 = g.point_at(999.0)
	assert_almost_eq(over.x, 2.5, 0.001)  # 超长截断到终点

func test_cell_to_pos_is_center():
	var g = GridScript.new(16, 10, WPS)
	var p: Vector2 = g.cell_to_pos(Vector2i(3, 4))
	assert_almost_eq(p.x, 3.5, 0.001)
	assert_almost_eq(p.y, 4.5, 0.001)
