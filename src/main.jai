
Sudoku :: struct {
    cells: [..]Cell;
}

Cell :: struct {
    value: int;
    text: [2]u8;
    has_conflict := false;
}

make_sudoku :: (serial: string) -> *Sudoku {
    using sudoku := New(Sudoku);

    chars := cast([]u8)serial;
    for chars {
        cell: Cell;
        if is_space(it) {
            continue;
        } else if it == #char "." {
            cell.value = -1;
            cell.text[0] = 0;
        } else if is_digit(it) {
            cell.value = it - #char "0";
            cell.text[0] = it;
            cell.text[1] = 0;
        } else {
            print("error: serial import string had invalid character: % (%)\n", it, cast(s32)it);
            return null;
        }
        array_add(*cells, cell);
    }

    return sudoku;
}

get_cell_ptr :: (using sudoku: *Sudoku, row: int, col: int) -> *Cell {
    return *cells[row * 9 + col];
}

get_cell :: (using sudoku: *Sudoku, row: int, col: int) -> Cell {
    return get_cell_ptr(sudoku, row, col).*;
}

get_cell_block_idx :: (row: int, col: int) -> int {
    return (row % 3) * 3 + col % 3;
}

get_row_col_block :: (using sudoku: *Sudoku, row: int, col: int) -> [9]Cell, [9]Cell, [9]Cell {
    row_arr: [9]Cell;
    for new_col: 0..8 {
        row_arr[new_col] = get_cell(sudoku, row, new_col);
    }

    col_arr: [9]Cell;
    for new_row: 0..8 {
        col_arr[new_row] = get_cell(sudoku, new_row, col);
    }

    block_arr: [9]Cell;
    block_col_base := (col / 3) * 3;
    block_row_base := (row / 3) * 3;
    for block_row: block_row_base..block_row_base + 2 {
        for block_col: block_col_base..block_col_base + 2 {
            block_arr[get_cell_block_idx(block_row, block_col)] = get_cell(sudoku, block_row, block_col);
        }
    }

    return row_arr, col_arr, block_arr;
}

is_duplicated :: (idx: int, sightline: []Cell) -> bool {
    cur := sightline[idx];
    if cur.value == -1 {
        return false;
    }
    for other, other_idx: sightline {
        if idx == other_idx continue;
        if cur.value == other.value {
            return true;
        }
    }
    return false;
}

check_conflicts :: (using sudoku: *Sudoku) {
    for row: 0..8 {
        for col: 0..8 {
            cell := get_cell_ptr(sudoku, row, col);
            if cell.value == -1 continue;

            row_arr, col_arr, block_arr := get_row_col_block(sudoku, row, col);
            cell.has_conflict = 
                is_duplicated(col, row_arr) 
                || is_duplicated(row, col_arr)
                || is_duplicated(get_cell_block_idx(row, col), block_arr);
        }
    }
}

Arguments :: struct {
    path: string;
}

main :: () {
    success, args, is_set := cmd_line.parse_arguments(Arguments);
    if !is_set.path {
        print("error: -path is required\n");
        return;
    }

    serial := file.read_entire_file(args.path);
    sudoku := make_sudoku(serial);
    check_conflicts(sudoku);
    if !sudoku {
        return;
    }

    screen_width: s32 = 1600;
    screen_height: s32 = 900;

    cell_size: s32 = min(screen_width / 10, screen_height / 10);
    cell_border: s32 = 1;
    board_border: s32 = 4;
    block_border: s32 = 2;
    cell_and_border_size := cell_size + cell_border * 2;
    board_size := cell_and_border_size * 9 + board_border * 2 + block_border * 2;

    positions: [..][2]s32;

    start_x := (screen_width - board_size) / 2;
    start_y := (screen_height - board_size) / 2;

    cell_cur := s32.[start_x + cell_border + board_border, start_y + cell_border + board_border];
    for 0..80 {
        if it != 0 && it % 9 == 0 {
            cell_cur[0] = start_x + cell_border + board_border;
            cell_cur[1] += cell_and_border_size;

            row := it / 9;
            if row == 3 || row == 6 {
                cell_cur[1] += block_border;
            }
        }
        array_add(*positions, cell_cur);
        cell_cur[0] += cell_and_border_size;

        col := it % 9;
        if col == 2 || col == 5 {
            cell_cur[0] += block_border;
        }
    }

    rl.InitWindow(screen_width, screen_height, "Sudoku");
    rl.SetTargetFPS(60);

    while !rl.WindowShouldClose() {
        rl.BeginDrawing();

        rl.ClearBackground(.{30, 30, 35, 255});

        rl.DrawRectangle(
            start_x,
            start_y,
            board_size,
            board_size,
            .{20, 100, 80, 255}
        );

        for positions {
            cell := *sudoku.cells[it_index];
            color := ifx cell.has_conflict then rl.Color.{150, 50, 50, 255} else .{50, 50, 50, 255};
            rl.DrawRectangle(it[0], it[1], cell_size, cell_size, color);
            font_size: s32 = 48;
            rl.DrawText(
                *cell.text[0],
                it[0] + cell_size / 2 - font_size / 4,
                it[1] + cell_size / 2 - font_size / 2,
                font_size, 
                .{20, 100, 80, 255}
            );
        }

        rl.EndDrawing();
    }

    rl.CloseWindow();
}

rl :: #import "raylib";
#import "Basic";
cmd_line :: #import "Command_Line";
file :: #import "File";