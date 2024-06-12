/*
	Marching Squares is an algorithm that takes a scalar field of at least 2x2 points
	It then "marches" through the scalar field, taking 4 points as a square at each iteration
	Using the values of the 4 points, a set of 2D lines may be constructed

	Requisites for mesh construction:
	- a threshold is set (usually called the isovalue)
	- at least one value must be below the threshold
	- at least one value must be above the threshold

	D -- C values must be ordered bottom left -> bottom right -> top right -> top left
	|    | this is consistent with graphics APIs that require counter-clockwise winding
	A -- B (will be useful when transitioning to marching cubes)

	Example:
	0---0 only the bottom right corner is above the threshold
	|  /| we must output a line from the bottom to the right sides
	0---1

	There are 16 configurations in total

    0b0000 configurations can be stored in 4-bits
	  DCBA each bit represents one of the corners

	So our goal is to take our scalar values, march through them creating squares, then
	calculating the configuration of the square and generating the lines.
*/

package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

determine_configuration :: proc(square: []u8) -> u8 {
	configuration := u8(0)
	for v, i in square {
		if v >= 8 {
			configuration |= 1 << u8(i)
		}
	}
	return configuration
}

vertex_interpolate :: proc(square: []u8, edge: u8) -> [2]f32 {
	//   0  
	// 3   1 edge order
	//   2 
	// TODO: Branchless version
	a, b: [2]f32
	switch edge {
	case 0:
		a.x = 1
		a.y = 1
		b.y = 1
	case 1:
		a.x = 1
		b.x = 1
		b.y = 1
	case 2:
		b.x = 1
	case 3:
		a.y = 1
	}

	// Just the midpoint for now!
	return a + (b - a) / 2
}

// takes a square made from 4 values in the scalar field
// the result is a slice of lines which may be empty
generate_lines :: proc(square: []u8, offset: [2]f32 = {0, 0}, scale: f32) -> [][2][2]f32 {
	lines := make([dynamic][2][2]f32)
	configuration := determine_configuration(square)
	square_index := edge_table[configuration]

	if square_index != 0 {
		vertices := make([][2]f32, 4)

		//   0  
		// 3   1 edge order
		//   2 
		// NOTE: Why this order? Because Raylib draws top to bottom
		for edge in 0 ..= 3 {
			if square_index & (1 << u8(edge)) > 0 {
				vertices[edge] = vertex_interpolate(square, u8(edge)) * scale + offset
			}
		}

		for i := 0; i + 1 < len(line_table[configuration]); i += 2 {
			vertex_a := vertices[line_table[configuration][i]]
			vertex_b := vertices[line_table[configuration][i + 1]]
			line := [2][2]f32{vertex_a, vertex_b}
			append(&lines, line)
		}
	}

	return lines[:]
}

square_from_mask :: proc(m: u8) -> [4]u8 {
	square: [4]u8
	for i in 0 ..= 3 {
		square[i] = u8(rand.uint32() % 8)
		if m & (1 << u8(i)) > 0 {
			square[i] += 8
		}
	}
	return square
}

SquareInstance :: struct {
	square: [4]u8,
	lines:  [][2][2]f32,
}

ScalarField :: struct {
	values: []u8,
	size:   [2]int,
	scale:  f32,
}

index_from_pos :: proc(p: [2]f32, width: int) -> int {
	return int(p.y * f32(width) + p.x)
}

pos_from_index :: proc(index, width: int) -> [2]f32 {
	x := f32(index % width)
	y := f32(index / width)
	return [2]f32{x, y}
}

main :: proc() {
	rl.InitWindow(1080, 720, "Marching Squares")
	rl.SetTargetFPS(60)
	lines := make([dynamic][2][2]f32)

	scalar_field := ScalarField {
		values = []u8{0, 0, 0, 0, 0, 15, 15, 0, 0, 15, 15, 0, 0, 0, 0, 0},
		size   = [2]int{4, 4},
		scale  = 20,
	}

	for x in 0 ..< scalar_field.size.x - 1 {
		for y in 0 ..< scalar_field.size.y - 1 {
			index := y * scalar_field.size.x + x
			square := [4]u8 {
				scalar_field.values[index + scalar_field.size.x],
				scalar_field.values[index + scalar_field.size.x + 1],
				scalar_field.values[index + 1],
				scalar_field.values[index],
			}
			offset := [2]f32{f32(x), f32(y)} * scalar_field.scale
			l := generate_lines(square[:], offset, scalar_field.scale)
			append(&lines, ..l)
		}
	}

	fmt.println(lines)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		{
			rl.ClearBackground(rl.BLACK)

			for x in 0 ..< scalar_field.size.x {
				for y in 0 ..< scalar_field.size.y {
					rl.DrawRectangleV({f32(x), f32(y)} * 20 + 20, {2, 2}, {255, 255, 255, 128})
					i := index_from_pos({f32(x), f32(y)}, scalar_field.size.x)
					// rl.DrawText(fmt.caprintf("%d", i), i32(x * 20), i32(y * 20), 10, rl.WHITE)
				}
			}

			for line in lines {
				rl.DrawLineV(line.x + 20, line.y + 20, rl.WHITE)
			}
		}
		rl.EndDrawing()
	}
}

edge_table := [16]u8 {
	0b0000,
	0b1001,
	0b0011,
	0b1010,
	0b0110,
	0b1111,
	0b0101,
	0b1001,
	0b1100,
	0b0101,
	0b1111,
	0b0110,
	0b1010,
	0b0011,
	0b1001,
	0b0000,
}

line_table := [16][]i8 {
	{},
	{0, 3},
	{0, 1},
	{1, 3},
	{1, 2},
	{1, 2, 3, 0},
	{0, 2},
	{0, 3},
	{2, 3},
	{0, 2},
	{0, 1, 2, 3},
	{1, 2},
	{1, 3},
	{0, 1},
	{0, 3},
	{},
}
