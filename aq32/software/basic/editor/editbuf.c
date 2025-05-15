#include "editbuf.h"

static uint8_t *getline_addr(struct editbuf *eb, int line) {
    line = clamp(line, 0, eb->line_count);

    uint8_t *p;
    int      count;

    if (eb->cached_p_line <= line) {
        p     = eb->cached_p;
        count = line - eb->cached_p_line;
    } else {
        p     = eb->p_buf;
        count = line;
    }

    while (count--)
        p += 1 + p[0];

    eb->cached_p      = p;
    eb->cached_p_line = line;

    return p;
}

static void invalidate_cached(struct editbuf *eb) {
    eb->cached_p      = eb->p_buf;
    eb->cached_p_line = 0;
}

static void compact(struct editbuf *eb) {
    uint8_t       *p_end = getline_addr(eb, eb->line_count);
    uint8_t       *pd    = eb->p_buf;
    const uint8_t *ps    = pd;

    while (ps < p_end) {
        const uint8_t *ps_next = ps + 1 + ps[0];
        ps++;
        unsigned count = *(ps++);

        *(pd++) = 1 + count;
        *(pd++) = count;
        while (count--)
            *(pd++) = *(ps++);

        ps = ps_next;
    }
    invalidate_cached(eb);
}

static bool resize_linebuffer(struct editbuf *eb, uint8_t *p, uint8_t new_size) {
    if (new_size < 1)
        return false;
    if (p[0] == new_size)
        return true;

    uint8_t *p_next = p + 1 + p[0];
    uint8_t *p_end  = getline_addr(eb, eb->line_count);

    if (p == p_end) {
        if (p + 1 + new_size > eb->p_buf_end)
            return false;

        p[0] = new_size;
        p[1] = 0;
        eb->line_count++;

    } else {
        uint8_t *p_new_next = p + 1 + new_size;
        if (p_end + (p_new_next - p_next) > eb->p_buf_end)
            return false;

        memmove(p_new_next, p_next, p_end - p_next);
        p[0] = new_size;
    }
    return true;
}

void editbuf_init(struct editbuf *eb, uint8_t *p, size_t size) {
    eb->line_count    = 0;
    eb->p_buf         = p;
    eb->p_buf_end     = p + size;
    eb->cached_p      = eb->p_buf;
    eb->cached_p_line = 0;
    eb->modified      = false;
}

void editbuf_reset(struct editbuf *eb) {
    eb->line_count    = 0;
    eb->cached_p      = eb->p_buf;
    eb->cached_p_line = 0;
    eb->modified      = false;
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

static bool _insert_ch(struct editbuf *eb, int line, int pos, char ch) {
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

    unsigned new_size = min(1 + cur_linesz + 15, MAX_BUFSZ);
    if (!resize_linebuffer(eb, p, new_size))
        return false;

    uint8_t *p_pos = p + 2 + pos;
    memmove(p_pos + 1, p_pos, cur_linesz - pos);
    *p_pos = ch;
    p[1]++;

    eb->modified = true;
    return true;
}

bool editbuf_insert_ch(struct editbuf *eb, int line, int pos, char ch) {
    bool result = _insert_ch(eb, line, pos, ch);
    if (!result) {
        compact(eb);
        result = _insert_ch(eb, line, pos, ch);
    }
    return result;
}

bool editbuf_delete_ch(struct editbuf *eb, int line, int pos) {
    if (line < 0 || line >= eb->line_count || pos < 0)
        return false;

    uint8_t *p = getline_addr(eb, line);
    if (pos > p[1])
        return false;

    uint8_t *p_pos = p + 2 + pos;

    if (pos == p[1]) {
        // Merge with next line
        if (line + 1 < eb->line_count) {
            uint8_t *pn        = p + 1 + p[0];
            uint8_t  pn_bufsz  = pn[0];
            uint8_t  pn_linesz = pn[1];
            if (p[1] + pn_linesz > MAX_LINESZ)
                return false;

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
    eb->modified = true;
    return true;
}

static bool _insert_line(struct editbuf *eb, int line, const char *s, size_t sz) {
    if (sz > MAX_LINESZ)
        sz = MAX_LINESZ;

    // FIXME
    if (line != eb->line_count)
        return false;

    uint8_t *p = getline_addr(eb, line);
    if (p + 2 + sz > eb->p_buf_end)
        return false;

    p[0] = sz + 1;
    p[1] = sz;
    memmove(p + 2, s, sz);

    eb->line_count++;
    eb->modified = true;
    return true;
}

bool editbuf_insert_line(struct editbuf *eb, int line, const char *s, size_t sz) {
    bool result = _insert_line(eb, line, s, sz);
    if (!result) {
        compact(eb);
        result = _insert_line(eb, line, s, sz);
    }
    return result;
}

static bool _split_line(struct editbuf *eb, int line, int pos) {
    if (line < 0 || line > eb->line_count || pos < 0)
        return false;

    uint8_t *p = getline_addr(eb, line);
    if (pos > p[1])
        return false;

    uint8_t *p_pos = p + 2 + pos;
    uint8_t *p_end = getline_addr(eb, eb->line_count);

    if (p == p_end) {
        if (p + 2 > eb->p_buf_end)
            return false;

        p[1] = 0;
        p[0] = p[1] + 1;

    } else {
        if (p_end + 2 > eb->p_buf_end)
            return false;

        memmove(p_pos + 2, p_pos, p_end - p_pos);
        p_pos[1] = p[1] - pos;
        p_pos[0] = p[0] - pos;
        p[1]     = pos;
        p[0]     = p[1] + 1;
    }

    eb->line_count++;
    invalidate_cached(eb);
    eb->modified = true;
    return true;
}

bool editbuf_split_line(struct editbuf *eb, int line, int pos) {
    bool result = _split_line(eb, line, pos);
    if (!result) {
        compact(eb);
        result = _split_line(eb, line, pos);
    }
    return result;
}

bool editbuf_convert_from_regular(struct editbuf *eb, const uint8_t *ps, const uint8_t *ps_end) {
    editbuf_reset(eb);

    uint8_t *pd     = eb->p_buf;
    uint8_t  len    = 0;
    uint8_t *p_line = pd;

    bool newline = true;
    while (ps < ps_end) {
        if (len == MAX_LINESZ) {
            eb->line_count++;
            p_line[0] = len + 1;
            p_line[1] = len;
            len       = 0;
            newline   = true;
        }
        if (newline) {
            p_line = pd;
            pd += 2;
            newline = false;
        }
        if (pd >= eb->p_buf_end || pd >= ps) {
            editbuf_reset(eb);
            return false;
        }

        uint8_t val = *(ps++);
        newline     = (val == '\r' || val == '\n');
        if (val == '\r' && ps[0] == '\n')
            ps++;

        if (newline) {
            eb->line_count++;
            p_line[0] = len + 1;
            p_line[1] = len;
            len       = 0;
        } else {
            *(pd++) = val;
            len++;
        }
    }
    if (len > 0) {
        eb->line_count++;
        p_line[0] = len + 1;
        p_line[1] = len;
    }
    return true;
}

int editbuf_convert_to_regular(struct editbuf *eb) {
    const uint8_t *ps = eb->p_buf;
    uint8_t       *pd = eb->p_buf;

    for (int i = 0; i < eb->line_count; i++) {
        const uint8_t *p_next    = ps + 1 + ps[0];
        uint8_t        line_size = ps[1];
        ps += 2;

        while (line_size--)
            *(pd++) = *(ps++);
        *(pd++) = '\n';

        ps = p_next;
    }
    editbuf_reset(eb);

    return pd - eb->p_buf;
}
