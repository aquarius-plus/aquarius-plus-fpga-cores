#include "common.h"
#include "editor/editor.h"
#include "basic/basic.h"
#include "video_save.h"

static void cmd_run_start(void);

static void cmd_view_output_screen();

static void cmd_help_index(void);
static void cmd_help_contents(void);
static void cmd_help_topic(void);
static void cmd_help_about(void);

static struct editbuf editbuf;

static const struct menu_item menu_file_items[] = {
    {.title = "&New", .shortcut = KEY_MOD_CTRL | 'N', .status = "Removes currently loaded file from memory", .handler = cmd_file_new},
    {.title = "&Open...", .shortcut = KEY_MOD_CTRL | 'O', .status = "Loads new file into memory", .handler = cmd_file_open},
    {.title = "&Save", .shortcut = KEY_MOD_CTRL | 'S', .status = "Saves current file", .handler = cmd_file_save},
    {.title = "Save &As...", .shortcut = KEY_MOD_SHIFT | KEY_MOD_CTRL | 'S', .status = "Saves current file with specified name", .handler = cmd_file_save_as},
    {.title = "-"},
    {.title = "E&xit", .shortcut = KEY_MOD_CTRL | 'Q', .status = "Exits editor and returns to system", .handler = cmd_file_exit},
    {.title = NULL},
};

// static const struct menu_item menu_edit_items[] = {
//     {.title = "Cu&t", .shortcut = KEY_MOD_CTRL | 'X'},
//     {.title = "&Copy", .shortcut = KEY_MOD_CTRL | 'C'},
//     {.title = "&Paste", .shortcut = KEY_MOD_CTRL | 'V'},
//     {.title = "-"},
//     {.title = "&Find", .shortcut = KEY_MOD_CTRL | 'F'},
//     {.title = "&Replace", .shortcut = KEY_MOD_CTRL | 'H'},
//     {.title = "-"},
//     {.title = "&Select all", .shortcut = KEY_MOD_CTRL | 'A'},
//     {.title = "-"},
//     {.title = "Format document", .shortcut = KEY_MOD_SHIFT | KEY_MOD_ALT | 'F'},
//     {.title = "Format selection"},
//     {.title = "Trim trailing whitespace"},
//     {.title = NULL},
// };

static const struct menu_item menu_view_items[] = {
    {.title = "&Output Screen", .shortcut = CH_F4, .status = "Displays output screen", .handler = cmd_view_output_screen},
    {.title = NULL},
};

static const struct menu_item menu_run_items[] = {
    {.title = "&Start", .shortcut = CH_F5, .status = "Runs current program", .handler = cmd_run_start},
    {.title = NULL},
};

static const struct menu_item menu_help_items[] = {
    {.title = "&Index", .status = "Displays help index", .handler = cmd_help_index},
    {.title = "&Contents", .status = "Display help table of contents", .handler = cmd_help_contents},
    {.title = "&Topic", .shortcut = CH_F1, .status = "Displays information about the keyword the cursor is on", .handler = cmd_help_topic},
    {.title = "-"},
    {.title = "&About...", .status = "Displays product version", .handler = cmd_help_about},
    {.title = NULL},
};

const struct menu menubar_menus[] = {
    {.title = "&File", .items = menu_file_items},
    // {.title = "&Edit", .items = menu_edit_items},
    {.title = "&View", .items = menu_view_items},
    {.title = "&Run", .items = menu_run_items},
    {.title = "&Help", .items = menu_help_items},
    {.title = NULL},
};

static void wait_keypress(void) {
    int key;
    while ((key = REGS->KEYBUF) >= 0);
    while (1) {
        while ((key = REGS->KEYBUF) < 0);
        if ((key & KEY_IS_SCANCODE) == 0) {
            break;
        }
    }
}

static void show_basic_error(int result) {
    editor_set_cursor(basic_get_error_line(), 0);
    reinit_video();
    editor_redraw_screen();
    dialog_message("Error", basic_get_error_str(result));
}

static void cmd_run_start(void) {
    scr_status_msg("Compiling...");
    int result = basic_compile(&editbuf);
    if (result != 0) {
        show_basic_error(result);
        return;
    }
    result = basic_run();
    save_video();
    if (result != 0) {
        show_basic_error(result);
        return;
    }

    scr_status_msg("Press any key to continue");
    int key;
    while ((key = REGS->KEYBUF) >= 0);
    while (1) {
        while ((key = REGS->KEYBUF) < 0);
        if ((key & KEY_IS_SCANCODE) == 0) {
            break;
        }
    }
    reinit_video();
}

static void cmd_view_output_screen(void) {
    restore_video();
    wait_keypress();
    reinit_video();
}

static void cmd_help_index(void) {
}

static void cmd_help_contents(void) {
}

static void cmd_help_topic(void) {
}

static void cmd_help_about(void) {
    dialog_message("About", "Aquarius32 BASIC v0.1");
}

static __attribute__((section(".noinit"))) uint8_t buf_edit[128 * 1024];

void main(void) {
    save_video();
    editbuf_init(&editbuf, buf_edit, sizeof(buf_edit));
    editor(&editbuf);
}
