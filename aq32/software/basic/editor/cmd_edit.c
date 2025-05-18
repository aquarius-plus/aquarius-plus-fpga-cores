#include "editor.h"
#include "editor_internal.h"

void cmd_edit_cut(void) {
    if (!has_selection())
        return;

    scr_status_msg("Writing to clipboard file...");
    update_selection_range();
    if (editbuf_save_range(state.editbuf, state.loc_selection_from, state.loc_selection_to, CLIPBOARD_PATH)) {
        editbuf_delete_range(state.editbuf, state.loc_selection_from, state.loc_selection_to);
        clear_selection();
    }
}

void cmd_edit_copy(void) {
    if (!has_selection())
        return;

    scr_status_msg("Writing to clipboard file...");
    update_selection_range();
    editbuf_save_range(state.editbuf, state.loc_selection_from, state.loc_selection_to, CLIPBOARD_PATH);
}

void cmd_edit_paste(void) {
    clear_selection();
    update_cursor_pos();
    editbuf_insert_from_file(state.editbuf, &state.loc_cursor, CLIPBOARD_PATH);
}

void cmd_edit_select_all(void) {
    state.loc_selection.line = 0;
    state.loc_selection.pos  = 0;
    state.loc_cursor.line    = editbuf_get_line_count(state.editbuf) - 1;
    state.loc_cursor.pos     = editbuf_get_line(state.editbuf, state.loc_cursor.line, NULL);
}

void cmd_edit_find(void) {
}

void cmd_edit_find_next(void) {
}
