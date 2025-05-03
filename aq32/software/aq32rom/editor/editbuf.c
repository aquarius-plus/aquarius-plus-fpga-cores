#include "editbuf.h"
#include "dialog.h"

static uint8_t *getline_addr(struct editbuf *eb, int line) {
    line = clamp(line, 0, eb->line_count);

    uint8_t *p;
    int      count;

    if (eb->cached_p_line <= line) {
        p     = eb->cached_p;
        count = line - eb->cached_p_line;
    } else {
        p     = eb->buf;
        count = line;
    }

    while (count--)
        p += 1 + p[0];

    eb->cached_p      = p;
    eb->cached_p_line = line;

    return p;
}

static void invalidate_cached(struct editbuf *eb) {
    eb->cached_p      = eb->buf;
    eb->cached_p_line = 0;
}

static void resize_linebuffer(struct editbuf *eb, uint8_t *p, uint8_t new_size) {
    if (p[0] == new_size)
        return;

    uint8_t *p_next = p + 1 + p[0];
    uint8_t *p_end  = getline_addr(eb, eb->line_count);

    if (p == p_end) {
        p[0] = new_size;
        p[1] = 0;
    } else {
        memmove(p + 1 + new_size, p_next, p_end - p_next);
        p[0] = new_size;
    }
    invalidate_cached(eb);
}

void editbuf_init(struct editbuf *eb) {
    eb->line_count    = 0;
    eb->cached_p      = eb->buf;
    eb->cached_p_line = 0;
}

int editbuf_get_line_count(struct editbuf *eb) {
    return eb->line_count;
}

int editbuf_get_line(struct editbuf *eb, int line, const uint8_t **p) {
    if (line < 0 || line >= eb->line_count)
        return -1;

    uint8_t *pl = getline_addr(eb, line);
    *p          = pl + 2;

    return pl[1];
}

bool editbuf_insert_ch(struct editbuf *eb, int line, int pos, char ch) {
    if (line < 0 || line > eb->line_count || pos < 0)
        return false;

    uint8_t *p          = getline_addr(eb, line);
    uint8_t  cur_linesz = 0;
    if (line < eb->line_count) {
        if (p[0] + 1 > MAX_BUFSZ)
            return false;

        cur_linesz = p[1];
    }
    if (pos > cur_linesz)
        return false;

    resize_linebuffer(eb, p, min(1 + cur_linesz + 15, MAX_BUFSZ));

    uint8_t *p_pos = p + 2 + pos;
    memmove(p_pos + 1, p_pos, cur_linesz - pos);
    *p_pos = ch;
    p[1]++;

    if (line == eb->line_count) {
        eb->line_count++;
    }
    return true;
}

void editbuf_delete_ch(struct editbuf *eb, int line, int pos) {
    if (line < 0 || line >= eb->line_count || pos < 0)
        return;

    uint8_t *p = getline_addr(eb, line);
    if (pos > p[1])
        return;

    uint8_t *p_pos = p + 2 + pos;

    if (pos == p[1]) {
        // Merge with next line
        if (line + 1 < eb->line_count) {
            uint8_t *pn        = p + 1 + p[0];
            uint8_t  pn_bufsz  = pn[0];
            uint8_t  pn_linesz = pn[1];
            if (p[1] + pn_linesz > MAX_LINESZ)
                return;

            uint8_t *p_end = getline_addr(eb, eb->line_count);
            uint8_t *pnn   = pn + 1 + pn_bufsz;

            memmove(p_pos, pn + 2, pn_linesz);
            p[1] += pn_linesz;

            unsigned new_bufsize = p[0] + 1 + pn_bufsz;
            if (new_bufsize > MAX_BUFSZ) {
                memmove(p + 1 + p[1] + 1, pnn, p_end - pnn);
                new_bufsize = p[1] + 1;
            }
            p[0] = new_bufsize;

            eb->line_count--;
        }

    } else {
        // Delete within line
        memmove(p_pos, p_pos + 1, p[1] - pos - 1);
        p[1]--;
    }

    if (p[1] == 0) {
        uint8_t *p_end = getline_addr(eb, eb->line_count);
        if (p + 1 + p[0] == p_end)
            eb->line_count--;
    }

    invalidate_cached(eb);
}

void editbuf_insert_line(struct editbuf *eb, int line, const char *s, size_t sz) {
    if (sz > MAX_LINESZ)
        sz = MAX_LINESZ;

    // FIXME
    if (line != eb->line_count)
        return;

    uint8_t *p = getline_addr(eb, line);
    p[0]       = sz + 1;
    p[1]       = sz;
    memmove(p + 2, s, sz);

    eb->line_count++;
}

void editbuf_split_line(struct editbuf *eb, int line, int pos) {
    if (line < 0 || line > eb->line_count || pos < 0)
        return;

    uint8_t *p = getline_addr(eb, line);
    if (pos > p[1])
        return;

    uint8_t *p_pos = p + 2 + pos;
    uint8_t *p_end = getline_addr(eb, eb->line_count);

    if (p == p_end) {
        p[1] = 0;
        p[0] = p[1] + 1;

    } else {
        memmove(p_pos + 2, p_pos, p_end - p_pos);
        p_pos[1] = p[1] - pos;
        p_pos[0] = p_pos[1] + 1;
        p[1]     = pos;
        p[0]     = p[1] + 1;
    }

    eb->line_count++;
    invalidate_cached(eb);
}
