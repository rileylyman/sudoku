IMMUTABLE_COLOR :: rl.Color.{0x1c, 0x1c, 0x1c, 0xff};
GUESS_COLOR :: rl.Color.{0x23, 0x23, 0x23, 0xff};
SCRATCH_COLOR :: rl.Color.{0x28, 0x28, 0x28, 0xff};
CONFLICT_COLOR :: rl.Color.{0xf2, 0x64, 0x19, 0xff};
SELECT_COLOR :: rl.Color.{0xa0, 0xa0, 0xa0, 0xff};
TEXT_COLOR :: rl.Color.{0xa0, 0xa0, 0xa0, 0xff};
BORDER_COLOR :: rl.Color.{0x10, 0x10, 0x10, 0xff};
BACKGROUND_COLOR :: rl.Color.{0x5, 0x5, 0x5, 0xff};

Sudoku :: struct {
    cells: [81]Cell;
    changed := false;
}

Cell :: struct {
    value := -1;
    candidates: u16 = 0;
    text: [2]u8;
    has_conflict := false;
    scratch_side := true;
    immutable := false;
}

update_cell_text :: (using cell: *Cell) {
    if value == -1 then text[0] = 0;
    else text[0] = xx (value + #char "0");
}

serialize :: (using sudoku: *Sudoku) -> string {
    builder: String_Builder = .{allocator = temp};

    for cells {
        if it_index % 9 == 3 || it_index % 9 == 6 {
            append(*builder, #char " ");
        } else if it_index % 9 == 0 && it_index > 0 {
            append(*builder, #char "\n");
        } 
        if it_index % 27 == 0 && it_index > 0 {
            append(*builder, #char "\n");
        }
        if it.value == -1 {
            append(*builder, #char ".");
        } else {
            append(*builder, cast(u8) it.value + #char "0");
        }
    }

    return builder_to_string(*builder, temp);
}

make_sudoku :: (serial: string) -> *Sudoku {
    using sudoku := New(Sudoku);

    cell_idx := 0;
    chars := cast([]u8)serial;
    for chars {
        cell: Cell;
        if is_space(it) {
            continue;
        } else if is_digit(it) {
            cell.value = it - #char "0";
           update_cell_text(*cell);
            cell.scratch_side = false;
            cell.immutable = true;
        } else if it != #char "." {
            print("error: serial import string had invalid character: % (%)\n", it, cast(s32)it);
            return null;
        }
        print("%\n", cell);
        cells[cell_idx] = cell;
        cell_idx += 1;
    }

    return sudoku;
}

pos_to_row_col :: (pos: int) -> int, int {
    return pos / 9, pos % 9;
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

put_number :: (using sudoku: *Sudoku, row: int, col: int, value: u8) {
    cell := get_cell_ptr(sudoku, row, col);
    if cell.immutable return;

    changed = true;

    if cell.scratch_side && (cell.candidates & (1 << (value - 1))) {
        cell.candidates &= xx ~(cast(u16) 1 << (value - 1));
    } else if cell.scratch_side {
        cell.candidates |= xx 1 << (value - 1);
    } else if cell.value == value {
        cell.value = -1;
        update_cell_text(cell);
    } else {
        cell.value = value;
        update_cell_text(cell);
    }
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
    if cur.value == -1 || cur.scratch_side {
        return false;
    }
    for other, other_idx: sightline {
        if idx == other_idx || other.scratch_side continue;
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

InputState :: struct {
    selected_row: u8 = 0;
    selected_col: u8 = 0;
}

main :: () {
    success, args, is_set := cmd_line.parse_arguments(Arguments);
    if !is_set.path {
        print("error: -path is required\n");
        return;
    }

    bin_file, bin_success := file.file_open(tprint("%.bin", args.path));
    txt_file, txt_success := file.file_open(tprint("%.txt", args.path));
    file.file_close(*bin_file);
    file.file_close(*txt_file);

    if !bin_success && !txt_success {
        print("error, %.txt and/or %1.bin does not exist and are required", args.path);
        return;
    }

    sudoku: *Sudoku;
    if bin_success {
        sudoku_buf := file.read_entire_file(tprint("%.bin", args.path));
        sudoku = cast(*Sudoku) sudoku_buf.data;
    } else {
        serial := file.read_entire_file(tprint("%.txt", args.path));
        defer free(serial);
        sudoku = make_sudoku(serial);
    }

    check_conflicts(sudoku);
    if !sudoku {
        return;
    }

    input_state: InputState;
    input_state.selected_row = 5;
    input_state.selected_col = 7;

    screen_width: s32 : 1000;
    screen_height: s32 : 1000;

    cell_size: s32 : #run min(screen_width / 10, screen_height / 10);
    cell_border: s32 : 2;
    board_border: s32 : 0;
    block_border: s32 : 8;
    cell_and_border_size :: cell_size + cell_border * 2;
    board_size :: cell_and_border_size * 9 + board_border * 2 + block_border * 2;

    positions: [..][2]s32;

    start_x :: (screen_width - board_size) / 2;
    start_y :: (screen_height - board_size) / 2;

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
    rl.SetTargetFPS(50);

    font_size :: 48.0;
    small_font_size :: font_size / 2;
    font := rl.LoadFontEx(temp_c_string("OverpassMono-Regular.ttf"), xx font_size, null, 0);

    down_key :: cast(s32) rl.KeyboardKey.J;
    up_key :: cast(s32) rl.KeyboardKey.K;
    left_key :: cast(s32) rl.KeyboardKey.H;
    right_key :: cast(s32) rl.KeyboardKey.L;
    flip_key :: cast(s32) rl.KeyboardKey.SPACE;
    one_key :: cast(s32) rl.KeyboardKey.ONE;
    two_key :: cast(s32) rl.KeyboardKey.TWO;
    three_key :: cast(s32) rl.KeyboardKey.THREE;
    four_key :: cast(s32) rl.KeyboardKey.Q;
    five_key :: cast(s32) rl.KeyboardKey.W;
    six_key :: cast(s32) rl.KeyboardKey.E;
    seven_key :: cast(s32) rl.KeyboardKey.A;
    eight_key :: cast(s32) rl.KeyboardKey.S;
    nine_key :: cast(s32) rl.KeyboardKey.D;

    while !rl.WindowShouldClose() {
        {
            using input_state;

            move_vert, move_hori : s8 = 0, 0;
            if rl.GetKeyPressed() == {
                case down_key;  move_vert = 1;
                case up_key;    move_vert = -1;
                case left_key;  move_hori = -1;
                case right_key; move_hori = 1;

                case one_key;   put_number(sudoku, selected_row, selected_col, 1);
                case two_key;   put_number(sudoku, selected_row, selected_col, 2);
                case three_key; put_number(sudoku, selected_row, selected_col, 3);
                case four_key;  put_number(sudoku, selected_row, selected_col, 4);
                case five_key;  put_number(sudoku, selected_row, selected_col, 5);
                case six_key;   put_number(sudoku, selected_row, selected_col, 6);
                case seven_key; put_number(sudoku, selected_row, selected_col, 7);
                case eight_key; put_number(sudoku, selected_row, selected_col, 8);
                case nine_key;  put_number(sudoku, selected_row, selected_col, 9);

                case flip_key;
                    cell := get_cell_ptr(sudoku, selected_row, selected_col);
                    if !cell.immutable then cell.scratch_side = !cell.scratch_side;
            }

            selected_row = xx ((xx selected_row + 9 + move_vert) % 9); 
            selected_col = xx ((xx selected_col + 9 + move_hori) % 9);
        }

        check_conflicts(sudoku);

        rl.BeginDrawing();

        rl.ClearBackground(BACKGROUND_COLOR);

        rl.DrawRectangle(
            start_x,
            start_y,
            board_size,
            board_size,
            BORDER_COLOR,
        );

        for pos, pos_idx: positions {
            cell := *sudoku.cells[pos_idx];
            color := ifx cell.immutable    then IMMUTABLE_COLOR
                else ifx cell.scratch_side then SCRATCH_COLOR
                else                            GUESS_COLOR;

            row, col := pos_to_row_col(pos_idx);
            cell_is_selected := row == input_state.selected_row && col == input_state.selected_col;
            draw_border := (pos: [2]s32, color: rl.Color) {
                rl.DrawRectangle(
                    pos[0] - cell_border * 2, 
                    pos[1] - cell_border * 2, 
                    cell_and_border_size + cell_border * 2, 
                    cell_and_border_size + cell_border * 2,
                    color,
                );
            }

            if cell.has_conflict draw_border(pos, CONFLICT_COLOR);
            if cell_is_selected draw_border(pos, SELECT_COLOR);

            rl.DrawRectangle(pos[0], pos[1], cell_size, cell_size, color);

            if !cell.scratch_side {
                rl.DrawTextEx(
                    font,
                    *cell.text[0],
                    .{
                    xx (pos[0] + cell_size / 2 - font_size / 4),
                    xx (pos[1] + cell_size / 2 - font_size / 2),
                    },
                    font_size, 
                    1.0,
                    TEXT_COLOR,
                );
            }

            if !cell.candidates || !cell.scratch_side continue;

            for candidate: 0..8 {
                if cell.candidates & (1 << candidate) == 0 continue;

                text := u8.[cast(u8) candidate + 1 + cast(u8) #char "0", 0];
                rl.DrawTextEx(
                    font,
                    *text[0],
                    .{
                    xx (pos[0] + (cast(s32) candidate % 3) * cell_size / 3  + cell_size / 6 - small_font_size / 4),
                    xx (pos[1] + (cast(s32) candidate / 3) * cell_size / 3  + cell_size / 6 - small_font_size / 2),
                    },
                    small_font_size,
                    1.0,
                    TEXT_COLOR
                );
            }
        }
        rl.EndDrawing();

        if sudoku.changed {
            sudoku.changed = false;
            // file.write_entire_file(tprint("%_saved.txt", args.path), serialize(sudoku));
            file.write_entire_file(tprint("%.bin", args.path), sudoku, size_of(Sudoku));
        }
        reset_temporary_storage();
    }

    rl.CloseWindow();
}

rl :: #import "raylib";
#import "Basic";
cmd_line :: #import "Command_Line";
file :: #import "File";